import Combine
import Foundation

@MainActor
final class CLILinkSettings: ObservableObject {
    private static let suppressionKey = "suppressCLILinkReminder"
    private let link: CLILink
    private let defaults: UserDefaults
    var didFinishInstallation: (() -> Void)?
    private(set) var authorizationPresentation: UUID?
    @Published private(set) var status: CLILink.Status
    @Published private(set) var installing = false
    @Published private(set) var message: String?
    @Published var suppressReminder: Bool {
        didSet { defaults.set(suppressReminder, forKey: Self.suppressionKey) }
    }

    init(link: CLILink = CLILink(), defaults: UserDefaults = .standard) {
        self.link = link
        self.defaults = defaults
        status = link.status
        suppressReminder = defaults.bool(forKey: Self.suppressionKey)
    }

    func refresh() {
        status = link.status
        if status == .installed { message = nil }
    }

    var shouldRemind: Bool { !suppressReminder && (status == .missing || status == .occupied) }

    func dismissPresentation(_ id: UUID) {
        if authorizationPresentation == id { authorizationPresentation = nil }
    }

    func install(from presentation: UUID) {
        guard !installing else { return }
        authorizationPresentation = presentation
        installing = true
        message = nil
        Task {
            do { try await Task.detached { [link] in try link.install() }.value } catch {
                message = error.localizedDescription
            }
            refresh()
            installing = false
            if authorizationPresentation == presentation {
                authorizationPresentation = nil
                didFinishInstallation?()
            }
        }
    }
}
