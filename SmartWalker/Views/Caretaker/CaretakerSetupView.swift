import SwiftUI

/// Caretaker mode: create and edit the home layout visually. The old room/connection
/// list has been replaced by `MapEditorView`, an editable indoor map where the
/// caretaker drags rooms, adds furniture, and draws doorways. Doorways become the
/// navigation connections the rest of the app already relies on.
struct CaretakerSetupView: View {
    var body: some View {
        MapEditorView()
    }
}
