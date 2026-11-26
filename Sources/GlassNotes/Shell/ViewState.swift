import SwiftUI

/// Use the SwiftUI property wrapper on both standalone Command Line Tools and Xcode.
/// In the 27 SDK the unqualified attribute can also resolve to an Xcode-only macro.
typealias ViewState<Value> = SwiftUI.State<Value>
