import Foundation
import AVFoundation

/// Captures one still photo from the back camera on demand and returns JPEG data.
/// Self-contained — it spins up its own brief capture session, so it does not depend
/// on the safety CameraManager. Returns nil if the camera is unavailable or denied.
enum SnapshotService {

    /// Best-effort snapshot. Never throws; returns nil on any problem so the caller
    /// can just send a text-only alert.
    static func capture() async -> Data? {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { return nil }
        } else if status != .authorized {
            return nil
        }
        return await withCheckedContinuation { (cont: CheckedContinuation<Data?, Never>) in
            Capturer.shared.capture { data in cont.resume(returning: data) }
        }
    }
}

/// Runs a single photo capture at a time on a private queue.
private final class Capturer: NSObject, AVCapturePhotoCaptureDelegate {
    static let shared = Capturer()

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.smartwalker.snapshot")
    private var completion: ((Data?) -> Void)?

    func capture(_ completion: @escaping (Data?) -> Void) {
        queue.async { [weak self] in
            guard let self else { completion(nil); return }
            self.completion = completion

            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                self.session.commitConfiguration()
            }

            if !self.session.isRunning { self.session.startRunning() }

            // Brief warm-up so the first frame isn't black.
            self.queue.asyncAfter(deadline: .now() + 0.5) {
                guard self.session.isRunning else { self.finish(nil); return }
                self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        finish(photo.fileDataRepresentation())
    }

    private func finish(_ data: Data?) {
        queue.async { [weak self] in
            if self?.session.isRunning == true { self?.session.stopRunning() }
        }
        let done = completion
        completion = nil
        DispatchQueue.main.async { done?(data) }
    }
}
