import CoreGraphics
import Testing
@testable import ZenotchKit

/// Values measured on a 13" MacBook Air M2 at the default scaled resolution.
private let airScreen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
private let airLeft = CGRect(x: 0, y: 1074.5, width: 751, height: 37.5)
private let airRight = CGRect(x: 959, y: 1074.5, width: 751, height: 37.5)

@Suite struct NotchGeometryTests {
    @Test func detectsAirNotch() throws {
        let notch = try #require(NotchGeometry.notchRect(screenFrame: airScreen, topLeftArea: airLeft, topRightArea: airRight))
        #expect(notch == CGRect(x: 751, y: 1074.5, width: 208, height: 37.5))
    }

    @Test func handlesScreenOffsetFromOrigin() throws {
        let screen = airScreen.offsetBy(dx: 1920, dy: -200)
        let notch = try #require(NotchGeometry.notchRect(screenFrame: screen, topLeftArea: airLeft, topRightArea: airRight))
        #expect(notch.minX == CGFloat(2671))
        #expect(notch.maxY == screen.maxY)
    }

    @Test func noNotchWithoutAuxiliaryAreas() {
        #expect(NotchGeometry.notchRect(screenFrame: airScreen, topLeftArea: nil, topRightArea: airRight) == nil)
        let full = CGRect(x: 0, y: 1074, width: 855, height: 38)
        #expect(NotchGeometry.notchRect(screenFrame: airScreen, topLeftArea: full, topRightArea: full) == nil)
    }

    @Test func fallbackIsCenteredUnderMenuBar() {
        let rect = NotchGeometry.fallbackRect(screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440), menuBarHeight: 25)
        #expect(rect.midX == 1280)
        #expect(rect.maxY == 1440)
        #expect(rect.height == 25)
    }

    @Test func panelStaysOnScreen() {
        let notch = CGRect(x: 10, y: 1074.5, width: 208, height: 37.5)
        let frame = NotchGeometry.panelFrame(notch: notch, size: CGSize(width: 700, height: 260), screenFrame: airScreen)
        #expect(frame.minX == 0)
        #expect(frame.maxY == airScreen.maxY)
    }

    @Test func hoverZoneIncludesScreenTopEdge() {
        let notch = CGRect(x: 751, y: 1074.5, width: 208, height: 37.5)
        let zone = NotchGeometry.hoverZone(notch: notch, size: notch.size)
        #expect(zone.contains(CGPoint(x: notch.midX, y: airScreen.maxY)))
        #expect(!zone.contains(CGPoint(x: notch.midX, y: notch.minY - 20)))
    }
}

@Suite struct NotchStateMachineTests {
    @Test func hoverPeeksAndClickExpands() {
        var machine = NotchStateMachine()
        #expect(machine.handle(.hoverEntered) == .peek)
        #expect(machine.handle(.clicked) == .expanded)
        #expect(machine.handle(.hoverExited) == .collapsed)
    }

    @Test func openOnHoverSkipsPeek() {
        var machine = NotchStateMachine(openOnHover: true)
        #expect(machine.handle(.hoverEntered) == .expanded)
    }

    @Test func dragAlwaysExpands() {
        var machine = NotchStateMachine()
        #expect(machine.handle(.dragEntered) == .expanded)
    }

    @Test func clickOutsideOnlyClosesWhenExpanded() {
        var machine = NotchStateMachine()
        machine.handle(.hoverEntered)
        #expect(machine.handle(.clickedOutside) == .peek)
        machine.handle(.clicked)
        #expect(machine.handle(.clickedOutside) == .collapsed)
    }

    @Test func hoverWhileExpandedDoesNothing() {
        var machine = NotchStateMachine()
        machine.handle(.clicked)
        #expect(machine.handle(.hoverEntered) == .expanded)
    }
}

@Suite struct NotchLayoutTests {
    let layout = NotchLayout(notchSize: CGSize(width: 208, height: 37.5))

    @Test func collapsedMatchesHardware() {
        #expect(layout.shapeSize(state: .collapsed, hasActivity: false) == CGSize(width: 208, height: 37.5))
    }

    @Test func activityAddsBothWings() {
        let size = layout.shapeSize(state: .collapsed, hasActivity: true)
        #expect(size.width == 208 + layout.wingWidth * 2)
    }

    @Test func panelFitsExpandedShape() {
        let expanded = layout.shapeSize(state: .expanded, hasActivity: false)
        #expect(layout.panelSize.width >= expanded.width + layout.cornerRadii(state: .expanded).top * 2)
        #expect(layout.panelSize.height >= expanded.height)
    }
}

@Suite struct LiveActivityTests {
    @Test func hudBeatsMedia() {
        let flash = HUDFlash(kind: .volume, level: 0.5)
        let result = LiveActivity.resolve(hud: flash, chargingFlash: false, batteryPercent: 80, timerFinishedFlash: false, timerRunning: true, mediaPlaying: true)
        #expect(result == .hud(flash))
    }

    @Test func timerBeatsMedia() {
        let result = LiveActivity.resolve(hud: nil, chargingFlash: false, batteryPercent: nil, timerFinishedFlash: false, timerRunning: true, mediaPlaying: true)
        #expect(result == .timer)
    }

    @Test func chargingNeedsPercent() {
        let result = LiveActivity.resolve(hud: nil, chargingFlash: true, batteryPercent: nil, timerFinishedFlash: false, timerRunning: false, mediaPlaying: false)
        #expect(result == nil)
    }
}
