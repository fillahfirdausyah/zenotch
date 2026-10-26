import AudioToolbox
import CoreAudio
import CoreGraphics
import Foundation
import Observation

/// Shows volume and brightness changes in the notch. Listens to CoreAudio and DisplayServices
/// change callbacks, so no Accessibility permission is needed. The system HUD still appears.
@MainActor
@Observable
final class HUDService {
    private(set) var flash: HUDFlash?

    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var outputDevice = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var volumeListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var muteListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var deviceListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var brightnessRegistered = false
    @ObservationIgnored private var lastBrightness: Float?
    @ObservationIgnored private var lastVolume: Float?
    @ObservationIgnored private var lastMuted: Bool?
    @ObservationIgnored private var started = false

    func start() {
        guard !started else { return }
        started = true
        observeDefaultDevice()
        attachVolumeListeners()
        registerBrightness()
    }

    func stop() {
        started = false
        detachVolumeListeners()
        if let deviceListener {
            var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, deviceListener)
        }
        deviceListener = nil
        hideTask?.cancel()
        flash = nil
    }

    fileprivate func brightnessChanged(_ value: Float) {
        guard started else { return }
        defer { lastBrightness = value }
        // DisplayServices also fires for auto-brightness drift; only show user-sized steps.
        if let lastBrightness, abs(lastBrightness - value) < 0.01 { return }
        show(HUDFlash(kind: .brightness, level: Double(value)))
    }

    private func show(_ flash: HUDFlash) {
        self.flash = flash
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.flash = nil
        }
    }

    private func volumeChanged() {
        guard started, outputDevice != kAudioObjectUnknown else { return }
        let volume = Self.volume(of: outputDevice)
        let muted = Self.isMuted(outputDevice)
        defer { lastVolume = volume; lastMuted = muted }
        guard let volume, volume != lastVolume || muted != lastMuted else { return }
        show(HUDFlash(kind: .volume, level: Double(volume), muted: muted))
    }

    private func observeDefaultDevice() {
        outputDevice = Self.defaultOutputDevice()
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.detachVolumeListeners()
                self.outputDevice = Self.defaultOutputDevice()
                self.lastVolume = nil
                self.attachVolumeListeners()
            }
        }
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        deviceListener = listener
    }

    private func attachVolumeListeners() {
        guard outputDevice != kAudioObjectUnknown else { return }
        lastVolume = Self.volume(of: outputDevice)
        lastMuted = Self.isMuted(outputDevice)
        let volume: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.volumeChanged() }
        }
        let mute: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.volumeChanged() }
        }
        var volumeAddress = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        var muteAddress = Self.address(kAudioDevicePropertyMute)
        AudioObjectAddPropertyListenerBlock(outputDevice, &volumeAddress, .main, volume)
        AudioObjectAddPropertyListenerBlock(outputDevice, &muteAddress, .main, mute)
        volumeListener = volume
        muteListener = mute
    }

    private func detachVolumeListeners() {
        guard outputDevice != kAudioObjectUnknown else { return }
        if let volumeListener {
            var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
            AudioObjectRemovePropertyListenerBlock(outputDevice, &address, .main, volumeListener)
        }
        if let muteListener {
            var address = Self.address(kAudioDevicePropertyMute)
            AudioObjectRemovePropertyListenerBlock(outputDevice, &address, .main, muteListener)
        }
        volumeListener = nil
        muteListener = nil
    }

    private func registerBrightness() {
        guard !brightnessRegistered, let display = Brightness.builtInDisplay() else { return }
        lastBrightness = Brightness.get(display)
        brightnessRegistered = Brightness.register(display: display, observer: self)
    }

    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func defaultOutputDevice() -> AudioObjectID {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return device
    }

    private static func volume(of device: AudioObjectID) -> Float? {
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        guard AudioObjectHasProperty(device, &address),
              AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr
        else { return nil }
        return volume
    }

    private static func isMuted(_ device: AudioObjectID) -> Bool {
        var muted = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = address(kAudioDevicePropertyMute)
        guard AudioObjectHasProperty(device, &address),
              AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr
        else { return false }
        return muted != 0
    }
}

/// Private DisplayServices calls, resolved at runtime so a missing symbol disables
/// the brightness HUD instead of crashing.
private enum Brightness {
    typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias RegisterFn = @convention(c) (CGDirectDisplayID, UnsafeRawPointer?, CFNotificationCallback) -> Int32

    static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)

    static func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &displays, &count)
        return displays.first { CGDisplayIsBuiltin($0) != 0 }
    }

    static func get(_ display: CGDirectDisplayID) -> Float? {
        guard let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        var value: Float = 0
        return unsafeBitCast(symbol, to: GetFn.self)(display, &value) == 0 ? value : nil
    }

    @MainActor
    static func register(display: CGDirectDisplayID, observer: HUDService) -> Bool {
        guard let symbol = dlsym(handle, "DisplayServicesRegisterForBrightnessChangeNotifications") else { return false }
        let context = UnsafeRawPointer(Unmanaged.passUnretained(observer).toOpaque())
        let result = unsafeBitCast(symbol, to: RegisterFn.self)(display, context) { _, observer, _, _, userInfo in
            guard let observer,
                  let info = userInfo as? [String: Any],
                  let value = (info["value"] as? NSNumber)?.floatValue
            else { return }
            let service = Unmanaged<HUDService>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async {
                MainActor.assumeIsolated { service.brightnessChanged(value) }
            }
        }
        return result == 0
    }
}
