import AppKit
import Observation

/// Runs the MediaRemote bridge inside /usr/bin/perl and mirrors its state.
@MainActor
@Observable
final class NowPlayingService {
    enum Status: Equatable {
        case starting
        case running
        case unavailable(String)
    }

    private(set) var status: Status = .starting
    private(set) var snapshot: NowPlayingSnapshot?
    private(set) var artwork: NSImage?
    private(set) var sourceApp: NSRunningApplication?

    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var input: FileHandle?
    @ObservationIgnored private var buffer = Data()
    @ObservationIgnored private var restarts = 0
    @ObservationIgnored private var stopping = false

    var isPlaying: Bool { snapshot?.playing == true && snapshot?.hasTrack == true }
    var hasTrack: Bool { snapshot?.hasTrack == true }

    func start() {
        guard process == nil else { return }
        stopping = false
        guard let library = Bundle.main.url(forResource: "libZenotchMediaBridge", withExtension: "dylib") else {
            status = .unavailable("Media bridge missing. Build the app with scripts/bundle.sh.")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            "-e",
            """
            use DynaLoader;
            my $lib = DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error();
            my $sym = DynaLoader::dl_find_symbol($lib, "zen_media_bridge_run") or die "symbol missing";
            DynaLoader::dl_install_xsub("main::run", $sym);
            &main::run();
            """,
            library.path,
        ]
        let stdout = Pipe()
        let stdin = Pipe()
        process.standardOutput = stdout
        process.standardInput = stdin
        process.standardError = FileHandle.nullDevice
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            // DispatchQueue.main keeps chunks in order; separate Tasks would not.
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.consume(data) } }
        }
        process.terminationHandler = { [weak self] proc in
            let code = proc.terminationStatus
            Task { @MainActor in self?.processExited(code: code) }
        }
        do {
            try process.run()
            self.process = process
            input = stdin.fileHandleForWriting
            status = .running
        } catch {
            status = .unavailable("Could not start the media bridge: \(error.localizedDescription)")
        }
    }

    func stop() {
        stopping = true
        try? input?.close()
        process?.terminate()
        process = nil
        input = nil
    }

    func send(_ command: String) {
        guard let input, let data = (command + "\n").data(using: .utf8) else { return }
        try? input.write(contentsOf: data)
    }

    func togglePlayPause() { send("toggle") }
    func next() { send("next") }
    func previous() { send("previous") }
    func seek(to seconds: Double) { send("seek \(seconds)") }

    func openSourceApp() {
        sourceApp?.activate()
    }

    private func consume(_ data: Data) {
        if data.isEmpty { return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let snapshot = NowPlayingSnapshot.decode(line: Data(line)) else { continue }
            apply(snapshot)
        }
    }

    private func apply(_ snapshot: NowPlayingSnapshot) {
        restarts = 0
        if snapshot.title != self.snapshot?.title || snapshot.playing != self.snapshot?.playing {
            log.debug("Now playing: \(snapshot.title ?? "-", privacy: .private) playing=\(snapshot.playing)")
        }
        if snapshot.artworkUnchanged != true {
            artwork = snapshot.artworkData.flatMap(NSImage.init(data:))
        }
        if snapshot.pid != self.snapshot?.pid {
            sourceApp = snapshot.pid > 0 ? Self.owningApp(of: snapshot.pid) : nil
        }
        self.snapshot = snapshot
    }

    /// Browsers play media from helper processes (like WebKit's GPU process); map those to the app the user sees.
    private static func owningApp(of pid: pid_t) -> NSRunningApplication? {
        typealias ResponsibleFn = @convention(c) (pid_t) -> pid_t
        var target = pid
        if let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") {
            let responsible = unsafeBitCast(symbol, to: ResponsibleFn.self)(pid)
            if responsible > 0 { target = responsible }
        }
        return NSRunningApplication(processIdentifier: target) ?? NSRunningApplication(processIdentifier: pid)
    }

    private func processExited(code: Int32) {
        process = nil
        input = nil
        guard !stopping else { return }
        restarts += 1
        log.error("Media bridge exited with code \(code), restart \(self.restarts)")
        if restarts > 3 {
            status = .unavailable("The media bridge keeps stopping (exit \(code)).")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(restarts)) { [weak self] in
            self?.start()
        }
    }
}
