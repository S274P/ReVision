import Foundation

/// Loads and saves the house layout locally as JSON in the app's Documents directory.
/// No network, no external services — the layout survives closing and reopening the app.
final class LayoutStore {
    static let shared = LayoutStore()

    // Bumped to v2 when the visual map (room frames + furniture) was added, so the
    // app seeds the new floor-plan sample instead of an older layout without geometry.
    private let filename = "house_layout_v2.json"
    private let queue = DispatchQueue(label: "com.smartwalker.layoutstore")

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(filename)
    }

    /// Loads the saved layout, or falls back to the sample home on first launch / errors.
    func load() -> HouseLayout {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(HouseLayout.self, from: data)
        } catch {
            // First run or unreadable file — seed with the sample layout.
            let sample = HouseLayout.sample()
            save(sample)
            return sample
        }
    }

    /// Persists the layout. Writes off the main thread; failures are logged, not fatal.
    func save(_ layout: HouseLayout) {
        queue.async { [fileURL] in
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(layout)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("[LayoutStore] save failed: \(error)")
            }
        }
    }
}
