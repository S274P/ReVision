import SwiftUI
import MessageUI

/// Presents the system Messages composer, pre-filled with recipients, body, and an
/// optional photo. The send is confirmed by the user in the standard Messages sheet.
struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var imageData: Data? = nil
    var onFinish: () -> Void

    /// Whether this device can send texts at all (false on Simulator / no SIM).
    static var canSend: Bool { MFMessageComposeViewController.canSendText() }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        if let imageData {
            vc.addAttachmentData(imageData, typeIdentifier: "public.jpeg", filename: "snapshot.jpg")
        }
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
            onFinish()
        }
    }
}
