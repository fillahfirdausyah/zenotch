import AppKit
@preconcurrency import AVFoundation
import Observation

/// Front camera preview. The session only runs while the Mirror tab is visible,
/// so the green camera light is never on in the background.
@MainActor
@Observable
final class MirrorService {
    enum Status: Equatable {
        case off
        case starting
        case running
        case denied
        case noCamera
    }

    private(set) var status: Status = .off

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private var configured = false
    @ObservationIgnored private let queue = DispatchQueue(label: "com.fillx.zenotch.mirror")

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            status = .starting
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted { self.run() } else { self.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        guard status == .running || status == .starting else { return }
        status = .off
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    private func run() {
        if !configured {
            guard configure() else {
                status = .noCamera
                return
            }
        }
        status = .running
        let session = session
        queue.async { if !session.isRunning { session.startRunning() } }
    }

    private func configure() -> Bool {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
        guard let device, let input = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .medium
        if session.canAddInput(input) { session.addInput(input) }
        session.commitConfiguration()
        configured = true
        return true
    }
}
