import SwiftUI

/// Top-level mode switcher. Big, clearly-labelled tabs for the three modes.
struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        TabView(selection: $app.mode) {
            UserNavigationView()
                .tabItem {
                    Label(AppMode.userNavigation.title,
                          systemImage: AppMode.userNavigation.systemImage)
                }
                .tag(AppMode.userNavigation)

            SafetyDetectionView()
                .tabItem {
                    Label(AppMode.safetyDetection.title,
                          systemImage: AppMode.safetyDetection.systemImage)
                }
                .tag(AppMode.safetyDetection)

            CaretakerSetupView()
                .tabItem {
                    Label(AppMode.caretakerSetup.title,
                          systemImage: AppMode.caretakerSetup.systemImage)
                }
                .tag(AppMode.caretakerSetup)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.light)
    }
}
