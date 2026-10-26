public enum NotchState: Equatable, Sendable {
    case collapsed
    case peek
    case expanded
}

public enum NotchEvent: Equatable, Sendable {
    case hoverEntered
    case hoverExited
    case clicked
    case clickedOutside
    case dragEntered
    case dismissed
}

public struct NotchStateMachine: Equatable, Sendable {
    public private(set) var state: NotchState = .collapsed
    public var openOnHover: Bool

    public init(openOnHover: Bool = false) {
        self.openOnHover = openOnHover
    }

    @discardableResult
    public mutating func handle(_ event: NotchEvent) -> NotchState {
        switch (state, event) {
        case (.collapsed, .hoverEntered):
            state = openOnHover ? .expanded : .peek
        case (.collapsed, .clicked), (.peek, .clicked):
            state = .expanded
        case (_, .dragEntered):
            state = .expanded
        case (.peek, .hoverExited), (.expanded, .hoverExited), (.expanded, .clickedOutside), (_, .dismissed):
            state = .collapsed
        default:
            break
        }
        return state
    }
}
