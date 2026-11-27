import Foundation

actor ReleaseCheck {
    static let shared = ReleaseCheck()
    private var retryAt = Date.distantPast
    static let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    private static let endpoint = URL(string: "https://api.github.com/repos/dc-orz/GlassNotes/releases/latest")!

    private struct Release: Decodable {
        let tag: String

        private enum CodingKeys: String, CodingKey {
            case tag = "tag_name"
        }
    }

    enum Status: Equatable {
        case available, upToDate, unknownInstalledVersion
    }

    struct Result {
        let latest: String
        let url: URL
        let status: Status
    }

    enum Failure: LocalizedError, Equatable {
        case noRelease, invalidResponse
        case rateLimited(until: Date)
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .noRelease: "GitHub 上还没有正式发布的版本。"
            case .rateLimited(let date):
                "GitHub 请求次数已达上限，可在 \(date.formatted(date: .omitted, time: .standard)) 后重试。"
            case .http(let status): "GitHub 返回 HTTP \(status)。"
            case .invalidResponse: "无法识别 GitHub 返回的版本信息。"
            }
        }
    }

    func latest(
        fetch: @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
            try await URLSession.shared.data(for: $0)
        }
    ) async throws -> Result {
        guard Date.now >= retryAt else { throw Failure.rateLimited(until: retryAt) }
        var request = URLRequest(
            url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await fetch(request)
        guard let response = response as? HTTPURLResponse else { throw Failure.invalidResponse }
        do {
            return try Self.result(data: data, response: response, installed: Self.installedVersion)
        } catch Failure.rateLimited(let date) {
            retryAt = max(retryAt, date)
            throw Failure.rateLimited(until: retryAt)
        }
    }

    static func result(data: Data, response: HTTPURLResponse, installed: String?, now: Date = .now) throws
        -> Result
    {
        switch response.statusCode {
        case 200: break
        case 404: throw Failure.noRelease
        case 403, 429:
            throw limitError(data: data, response: response, now: now)
        default: throw Failure.http(response.statusCode)
        }
        guard let release = try? JSONDecoder().decode(Release.self, from: data) else {
            throw Failure.invalidResponse
        }
        let latest = release.tag.hasPrefix("v") ? String(release.tag.dropFirst()) : release.tag
        guard let remote = components(latest) else { throw Failure.invalidResponse }
        let status: Status
        if let installed, let local = components(installed) {
            status = local.lexicographicallyPrecedes(remote) ? .available : .upToDate
        } else {
            status = .unknownInstalledVersion
        }
        let url = URL(string: "https://github.com/dc-orz/GlassNotes/releases/tag/")!.appendingPathComponent(
            release.tag)
        return Result(latest: latest, url: url, status: status)
    }

    private static func limitError(data: Data, response: HTTPURLResponse, now: Date) -> Failure {
        struct GitHubError: Decodable { let message: String }
        let exhausted = response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0"
        let delay = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
        let message = try? JSONDecoder().decode(GitHubError.self, from: data).message
        guard
            response.statusCode == 429 || exhausted || delay != nil
                || message?.localizedCaseInsensitiveContains("rate limit") == true
        else { return .http(response.statusCode) }

        var deadlines: [Date] = []
        if let delay, delay >= 0 { deadlines.append(now.addingTimeInterval(TimeInterval(delay))) }
        if exhausted, let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Int.init) {
            deadlines.append(Date(timeIntervalSince1970: TimeInterval(reset)))
        }
        return .rateLimited(until: deadlines.max() ?? now.addingTimeInterval(60))
    }

    // Bundle versions and published tags use dotted decimal components. 1.2 and 1.2.0 compare equally.
    private static func components(_ value: String) -> [Int]? {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.utf8.allSatisfy({ (48...57).contains($0) }), let number = Int(part) else {
                return nil
            }
            numbers.append(number)
        }
        guard !numbers.isEmpty else { return nil }
        while numbers.last == 0 { numbers.removeLast() }
        return numbers
    }
}
