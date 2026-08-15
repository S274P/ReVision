import Foundation
import AVFoundation
import CoreVideo
import Combine

/// Owns the AVCaptureSession, streams frames from the rear camera, and hands each
/// pixel buffer to a delegate closure for analysis. The preview layer is exposed for
/// SwiftUI to display.
final class CameraManager: NSObject, ObservableObject {

    @Published var isRunning = false
    @Published var authorized = false
    /// Human-readable reason the camera couldn't start, for showing in the UI.
    @Published var lastError: String?

    let session = AVCaptureSession()
    /// Called on the video queue with each frame. Keep the work light / throttled.
    var onFrame: (CVPixelBuffer) -> Void = { _ in }

    private let videoQueue = DispatchQueue(label: "com.smartwalker.camera.video")
    private let output = AVCaptureVideoDataOutput()
    private var configured = false

    // MARK: - Permission

    func requestAuthorization() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorized = granted
        default:
            authorized = false
        }
    }

    // MARK: - Session lifecycle

    func start() {
        guard authorized else {
            print("[CameraManager] start skipped: not authorized")
            return
        }
        videoQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured { self.configure() }
            if self.configured, !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.isRunning = self.session.isRunning }
        }
    }

    func stop() {
        videoQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        // 1) Find a camera device (with fallbacks if the default rear cam isn't returned).
        guard let device = Self.findCameraDevice() else {
            fail("No camera device found on this phone.")
            return
        }

        // 2) Build the input — surface the real error instead of swallowing it.
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            fail("Camera is busy or unavailable (\(error.localizedDescription)). "
                 + "Close other camera apps or restart the phone.")
            return
        }

        // 3) Attach the input.
        guard session.canAddInput(input) else {
            fail("Could not attach the camera input (\(device.localizedName)).")
            return
        }
        session.addInput(input)

        // 4) Frame output for the detector.
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }

        // Portrait orientation to match the mounted phone.
        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        configured = true
        DispatchQueue.main.async { self.lastError = nil }
        print("[CameraManager] configured OK with \(device.localizedName)")
    }

    /// Try the default rear camera, then progressively broader searches.
    private static func findCameraDevice() -> AVCaptureDevice? {
        if let d = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return d
        }
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera
        ]
        let back = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .back)
        if let d = back.devices.first { return d }
        let any = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified)
        return any.devices.first ?? AVCaptureDevice.default(for: .video)
    }

    private func fail(_ reason: String) {
        configured = false
        print("[CameraManager] camera unavailable: \(reason)")
        DispatchQueue.main.async { self.lastError = reason }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame(pixelBuffer)
    }
}
