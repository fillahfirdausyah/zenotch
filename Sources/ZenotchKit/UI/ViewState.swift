import SwiftUI

/// The macOS 27 SDK turns `@State` into a macro whose plugin ships only with Xcode.
/// Spelling the property wrapper through an alias keeps Command Line Tools builds working.
typealias ViewState<Value> = SwiftUI.State<Value>
