import NoteCore
import NoteDesign

extension Ink {
    var label: String {
        switch self {
        case .automatic: "自动"
        case .chalk: "瓷白"
        case .carbon: "炭黑"
        case .petrol: "深青"
        }
    }

    var style: InkStyle {
        switch self {
        case .automatic: .automatic
        case .chalk: .chalk
        case .carbon: .carbon
        case .petrol: .petrol
        }
    }
}
