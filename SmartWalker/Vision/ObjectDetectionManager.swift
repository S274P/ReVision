import Foundation
@preconcurrency import Vision
import CoreML
@preconcurrency import CoreVideo
import Combine

/// Runs a Core ML object detector over camera frames using Vision, throttled so we
/// don't analyze every single frame, and reports the detected objects.
///
/// ## Choosing a model
/// The app looks for these models in order and uses the first one bundled, so you can
/// upgrade accuracy just by dragging a bigger model into the project — no code change.
/// Bigger = more accurate but larger/slower. Tiny is the lightweight fallback.
@MainActor
final class ObjectDetectionManager: ObservableObject {

    /// Preferred detectors, most accurate first. Add any of these `.mlmodel` files to
    /// the app target; the first one found wins.
    static let modelNames = [
        "YOLOv3",            // full — most accurate (248 MB)
        "YOLOv3FP16",        // full, half precision (124 MB)
        "YOLOv3Int8LUT",     // full, quantized (62 MB)
        "YOLOv3Tiny",        // lightweight fallback (35 MB)
        "YOLOv3TinyFP16",
        "YOLOv3TinyInt8LUT"
    ]

    enum Status: Equatable {
        case notLoaded
        case ready
        case error(String)
    }

    @Published private(set) var status: Status = .notLoaded
    @Published private(set) var objects: [DetectedObject] = []
    /// Which model actually loaded (for the status line).
    private(set) var loadedName: String = ""

    var onDetections: ([DetectedObject]) -> Void = { _ in }

    private var request: VNCoreMLRequest?
    private var lastAnalysis = Date.distantPast
    private let minInterval: TimeInterval = 0.2
    private var isAnalyzing = false

    init() {
        loadModel()
    }

    /// Find the first bundled model from the preference list.
    private func findModel() -> (url: URL, name: String)? {
        for name in Self.modelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: name, withExtension: "mlmodel") {
                return (url, name)
            }
        }
        return nil
    }

    private func loadModel() {
        guard let found = findModel() else {
            status = .notLoaded
            return
        }
        do {
            let mlModel = try MLModel(contentsOf: found.url)
            let vnModel = try VNCoreMLModel(for: mlModel)
            let req = VNCoreMLRequest(model: vnModel, completionHandler: { [weak self] request, _ in
                self?.handle(request)
            })
            req.imageCropAndScaleOption = .scaleFill
            self.request = req
            self.loadedName = found.name
            status = .ready
        } catch {
            status = .error("Failed to load model: \(error.localizedDescription)")
        }
    }

    /// Feed a camera frame. Throttled internally; safe to call at full frame rate.
    nonisolated func analyze(_ pixelBuffer: CVPixelBuffer) {
        Task { @MainActor in
            guard self.status == .ready, let request = self.request else { return }
            let now = Date()
            guard !self.isAnalyzing, now.timeIntervalSince(self.lastAnalysis) >= self.minInterval else { return }
            self.isAnalyzing = true
            self.lastAnalysis = now

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
                Task { @MainActor in self.isAnalyzing = false }
            }
        }
    }

    private func handle(_ request: VNRequest) {
        let results = (request.results as? [VNRecognizedObjectObservation]) ?? []
        let detected: [DetectedObject] = results.compactMap { obs in
            guard let top = obs.labels.first else { return nil }
            return DetectedObject(label: top.identifier,
                                  confidence: top.confidence,
                                  boundingBox: obs.boundingBox)
        }
        Task { @MainActor in
            self.objects = detected
            self.onDetections(detected)
        }
    }

    var statusText: String {
        switch status {
        case .notLoaded: return "Detector not loaded (add a Core ML model)"
        case .ready:     return loadedName.isEmpty ? "Detecting" : "Detecting with \(loadedName)"
        case .error(let m): return m
        }
    }
}
