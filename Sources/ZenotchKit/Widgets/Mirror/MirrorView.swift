import AVFoundation
import SwiftUI

struct MirrorView: View {
    let service: MirrorService

    var body: some View {
        Group {
            switch service.status {
            case .denied:
                WidgetMessage(
                    symbol: "video.slash",
                    title: "Camera access is off",
                    detail: "Turn on Zenotch in Privacy & Security, Camera.",
                    actionTitle: "Open Privacy Settings",
                    action: service.openPrivacySettings
                )
            case .noCamera:
                WidgetMessage(symbol: "video.slash", title: "No camera found", detail: "Close apps that use the camera, then reopen this tab.")
            case .off, .starting:
                LoadingMessage(title: "Starting camera")
            case .running:
                HStack(spacing: 20) {
                    CameraPreview(session: service.session)
                        .frame(width: 240, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mirror").font(.system(size: 15, weight: .semibold)).foregroundStyle(Style.primary)
                        Text("Check yourself before a call. The camera turns off when you leave this tab or close the notch.")
                            .font(.system(size: 12))
                            .foregroundStyle(Style.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
            }
        }
        .onAppear(perform: service.start)
        .onDisappear(perform: service.stop)
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.automaticallyAdjustsVideoMirroring = false
        layer.connection?.isVideoMirrored = true
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
