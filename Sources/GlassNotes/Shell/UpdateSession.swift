import Combine
import Foundation

@MainActor
final class UpdateSession: ObservableObject {
    enum Phase {
        case checking
        case checked(ReleaseCheck.Result)
        case checkFailed(String, retryAt: Date?)
        case installing(ReleasePackage)
        case installFailed(ReleaseCheck.Result, String)
        case installed(String)
    }

    @Published private(set) var phase = Phase.checking
    private var latestCheck = UUID()
    private let checkForUpdate: @MainActor () async throws -> ReleaseCheck.Result
    private let installPackage: @MainActor (ReleasePackage) async throws -> Void

    init(
        checkForUpdate: @escaping @MainActor () async throws -> ReleaseCheck.Result = {
            try await ReleaseCheck.shared.latest()
        },
        installPackage: @escaping @MainActor (ReleasePackage) async throws -> Void = {
            try await UpdateInstaller.install($0)
        }
    ) {
        self.checkForUpdate = checkForUpdate
        self.installPackage = installPackage
    }

    func check(refreshAfterFailure: Bool = false) async {
        switch phase {
        case .installing, .installed: return
        case .installFailed where !refreshAfterFailure: return
        case .checking, .checked, .checkFailed, .installFailed: break
        }
        let requestID = UUID()
        latestCheck = requestID
        phase = .checking
        do {
            let result = try await checkForUpdate()
            guard !Task.isCancelled, latestCheck == requestID else { return }
            phase = .checked(result)
        } catch {
            guard !Task.isCancelled, latestCheck == requestID else { return }
            if case ReleaseCheck.Failure.rateLimited(let date) = error {
                phase = .checkFailed(error.localizedDescription, retryAt: date)
            } else {
                phase = .checkFailed(error.localizedDescription, retryAt: nil)
            }
        }
    }

    func install() {
        let result: ReleaseCheck.Result
        switch phase {
        case .checked(let release), .installFailed(let release, _): result = release
        default: return
        }
        guard result.status == .available, let package = result.package else { return }
        phase = .installing(package)
        // Closing the transient menu panel must not interrupt an authorized installation.
        Task {
            do {
                try await installPackage(package)
                phase = .installed(package.version)
            } catch {
                phase = .installFailed(result, error.localizedDescription)
            }
        }
    }
}
