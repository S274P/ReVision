import SwiftUI

/// Safety mode: shows the live camera with a zone overlay and the current warning.
/// Runs alongside navigation; warnings interrupt navigation speech automatically.
struct SafetyDetectionView: View {
    @EnvironmentObject private var app: AppState

    private var bannerColor: Color {
        switch app.safety.lastUrgency {
        case .stop:    return Theme.danger
        case .caution: return Theme.caution
        case .none:    return Theme.safe
        }
    }

    var body: some View {
        ZStack {
            if app.camera.authorized {
                CameraPreviewView(session: app.camera.session)
                    .ignoresSafeArea()
                zoneOverlay
            } else {
                Theme.background.ignoresSafeArea()
                permissionPrompt
            }

            VStack {
                Spacer()
                warningBanner
                detectorStatusBar
            }
            .padding(20)
        }
        .task {
            await app.requestCameraPermissions()
            app.startSafety()
        }
        .onDisappear { /* keep running if navigation still wants it */ }
    }

    // Visual guide lines splitting left / center / right zones.
    private var zoneOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Path { p in
                p.move(to: CGPoint(x: w * 0.38, y: 0))
                p.addLine(to: CGPoint(x: w * 0.38, y: geo.size.height))
                p.move(to: CGPoint(x: w * 0.62, y: 0))
                p.addLine(to: CGPoint(x: w * 0.62, y: geo.size.height))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }

    private var warningBanner: some View {
        Text(app.safety.lastWarning)
            .font(Theme.title)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding()
            .background(bannerColor.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .accessibilityLabel(Text(app.safety.lastWarning))
    }

    private var detectorStatusBar: some View {
        HStack(spacing: 10) {
            Image(systemName: app.detector.status == .ready ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(app.detector.status == .ready ? Theme.safe : Theme.caution)
            Text(app.detector.statusText)
                .font(Theme.label)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer()
        }
        .padding(14)
        .background(Theme.surface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }

    private var permissionPrompt: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.accent)
            Text("Camera access is needed to detect obstacles.")
                .font(Theme.body)
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
            BigButton(title: "Enable camera", systemImage: "camera") {
                Task {
                    await app.requestCameraPermissions()
                    app.startSafety()
                }
            }
        }
        .padding(30)
    }
}
