import Foundation
import Testing
@testable import ZenotchKit

@Suite struct NowPlayingSnapshotTests {
    @Test func decodesBridgeLine() throws {
        let line = #"{"pid":42,"playing":true,"title":"Song","artist":"Band","duration":200,"elapsed":10,"rate":1,"timestamp":1000}"#
        let snapshot = try #require(NowPlayingSnapshot.decode(line: Data(line.utf8)))
        #expect(snapshot.title == "Song")
        #expect(snapshot.hasTrack)
    }

    @Test func noTrackWithoutPlayer() throws {
        let snapshot = try #require(NowPlayingSnapshot.decode(line: Data(#"{"pid":0,"playing":false}"#.utf8)))
        #expect(!snapshot.hasTrack)
    }

    @Test func rejectsGarbage() {
        #expect(NowPlayingSnapshot.decode(line: Data("not json".utf8)) == nil)
    }

    @Test func extrapolatesElapsedWhilePlaying() throws {
        let line = #"{"pid":1,"playing":true,"title":"x","duration":200,"elapsed":10,"rate":1,"timestamp":1000}"#
        let snapshot = try #require(NowPlayingSnapshot.decode(line: Data(line.utf8)))
        #expect(snapshot.estimatedElapsed(at: Date(timeIntervalSince1970: 1005)) == 15)
        #expect(snapshot.estimatedElapsed(at: Date(timeIntervalSince1970: 5000)) == 200)
    }

    @Test func pausedElapsedDoesNotMove() throws {
        let line = #"{"pid":1,"playing":false,"title":"x","elapsed":10,"timestamp":1000}"#
        let snapshot = try #require(NowPlayingSnapshot.decode(line: Data(line.utf8)))
        #expect(snapshot.estimatedElapsed(at: Date(timeIntervalSince1970: 1100)) == 10)
    }

    @Test func formatsClock() {
        #expect(TimeFormat.clock(65) == "1:05")
        #expect(TimeFormat.clock(3725) == "1:02:05")
        #expect(TimeFormat.clock(-3) == "0:00")
    }
}

@Suite struct BatteryInfoTests {
    @Test func parsesDischarging() throws {
        let info = try #require(BatteryInfo(description: [
            "Type": "InternalBattery", "Current Capacity": 64, "Max Capacity": 100,
            "Is Charging": false, "Power Source State": "Battery Power", "Time to Empty": 185,
        ]))
        #expect(info.percent == 64)
        #expect(info.statusText == "3h 5m left")
    }

    @Test func chargingWithoutEstimate() throws {
        let info = try #require(BatteryInfo(description: [
            "Type": "InternalBattery", "Current Capacity": 30, "Max Capacity": 100,
            "Is Charging": true, "Power Source State": "AC Power", "Time to Full Charge": -1,
        ]))
        #expect(info.minutesRemaining == nil)
        #expect(info.statusText == "Charging")
    }

    @Test func ignoresNonBatterySources() {
        #expect(BatteryInfo(description: ["Type": "UPS"]) == nil)
    }
}

@Suite struct CountdownTimerTests {
    let start = Date(timeIntervalSince1970: 0)

    @Test func countsDown() {
        var timer = CountdownTimer()
        timer.start(duration: 60, now: start)
        #expect(timer.remaining(now: start.addingTimeInterval(15)) == 45)
        #expect(timer.progress(now: start.addingTimeInterval(30)) == 0.5)
        #expect(timer.isFinished(now: start.addingTimeInterval(60)))
    }

    @Test func pauseFreezesRemaining() {
        var timer = CountdownTimer()
        timer.start(duration: 60, now: start)
        timer.pause(now: start.addingTimeInterval(20))
        #expect(timer.remaining(now: start.addingTimeInterval(500)) == 40)
        timer.resume(now: start.addingTimeInterval(500))
        #expect(timer.remaining(now: start.addingTimeInterval(510)) == 30)
    }

    @Test func addExtendsDuration() {
        var timer = CountdownTimer()
        timer.start(duration: 60, now: start)
        timer.add(60, now: start)
        #expect(timer.remaining(now: start) == 120)
        #expect(timer.progress(now: start.addingTimeInterval(60)) == 0.5)
    }

    @Test func ignoresZeroDuration() {
        var timer = CountdownTimer()
        timer.start(duration: 0, now: start)
        #expect(!timer.isActive)
    }
}

@Suite struct ClipboardHistoryTests {
    @Test func dedupesAndOrders() {
        var history = ClipboardHistory()
        history.record("a", at: Date())
        history.record("b", at: Date())
        history.record("a", at: Date())
        #expect(history.entries.map(\.text) == ["a", "b"])
    }

    @Test func enforcesLimit() {
        var history = ClipboardHistory(limit: 3)
        for index in 0..<5 { history.record("\(index)", at: Date()) }
        #expect(history.entries.map(\.text) == ["4", "3", "2"])
    }

    @Test func skipsBlankAndConcealed() {
        var history = ClipboardHistory()
        history.record("   \n", at: Date())
        #expect(history.entries.isEmpty)
        #expect(!ClipboardHistory.shouldRecord(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
        #expect(ClipboardHistory.shouldRecord(types: ["public.utf8-plain-text"]))
    }

    @Test func previewUsesFirstLine() {
        #expect(ClipboardEntry(text: "  first  \nsecond", copiedAt: Date()).preview == "first")
    }
}

@Suite struct WeatherTests {
    @Test func decodesOpenMeteo() throws {
        let json = #"{"current":{"temperature_2m":29.4,"weather_code":2,"is_day":1},"daily":{"temperature_2m_max":[32.1],"temperature_2m_min":[24.0]}}"#
        let report = try #require(try JSONDecoder().decode(OpenMeteoResponse.self, from: Data(json.utf8)).report)
        #expect(report.condition == .partlyCloudy)
        #expect(report.high == 32.1)
    }

    @Test func mapsWmoCodes() {
        #expect(WeatherCondition(code: 0) == .clear)
        #expect(WeatherCondition(code: 63) == .rain)
        #expect(WeatherCondition(code: 96) == .thunderstorm)
        #expect(WeatherCondition(code: 1234) == .unknown)
    }

    @Test func buildsRequestURL() throws {
        let url = try #require(OpenMeteoResponse.url(latitude: -6.2146, longitude: 106.8451, fahrenheit: true))
        let query = url.query ?? ""
        #expect(query.contains("latitude=-6.215"))
        #expect(query.contains("temperature_unit=fahrenheit"))
    }
}

@Suite struct ShelfContentsTests {
    @Test func movesDuplicateToFront() {
        var contents = ShelfContents()
        let a1 = ShelfItem(name: "a", bookmark: Data([1]), addedAt: Date())
        let b = ShelfItem(name: "b", bookmark: Data([2]), addedAt: Date())
        let a2 = ShelfItem(name: "a", bookmark: Data([1]), addedAt: Date())
        let resolve: (ShelfItem) -> URL? = { URL(fileURLWithPath: "/tmp/" + $0.name) }
        contents.add(a1, resolving: resolve)
        contents.add(b, resolving: resolve)
        contents.add(a2, resolving: resolve)
        #expect(contents.items.map(\.id) == [a2.id, b.id])
    }

    @Test func prunesMissing() {
        var contents = ShelfContents(items: [
            ShelfItem(name: "keep", bookmark: Data(), addedAt: Date()),
            ShelfItem(name: "gone", bookmark: Data(), addedAt: Date()),
        ])
        contents.prune { $0.name == "keep" ? URL(fileURLWithPath: "/tmp/keep") : nil }
        #expect(contents.items.map(\.name) == ["keep"])
    }

    @Test func roundTripsRealFileBookmark() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zenotch-shelf-\(UUID().uuidString).txt")
        try Data("hi".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let item = try #require(ShelfItem(url: url))
        #expect(item.resolveURL()?.standardizedFileURL.resolvingSymlinksInPath() == url.standardizedFileURL.resolvingSymlinksInPath())
    }
}

@Suite struct BridgeProtocolTests {
    /// NSJSONSerialization writes Boolean values from MediaRemote as 1/0 unless they are NSNumber booleans.
    @Test func rejectsNumericBool() {
        #expect(NowPlayingSnapshot.decode(line: Data(#"{"pid":1,"playing":1}"#.utf8)) == nil)
        #expect(NowPlayingSnapshot.decode(line: Data(#"{"pid":1,"playing":true}"#.utf8)) != nil)
    }
}
