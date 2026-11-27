import Foundation
import Testing

@testable import GlassNotes

struct ReleaseCheckTests {
    private let now = Date(timeIntervalSince1970: 1000)
    private func result(_ body: String, installed: String?, http: Int = 200, headers: [String: String]? = nil)
        throws -> ReleaseCheck.Result
    {
        let response = try #require(
            HTTPURLResponse(
                url: URL(fileURLWithPath: "/"), statusCode: http, httpVersion: "HTTP/1.1", headerFields: headers))
        return try ReleaseCheck.result(data: Data(body.utf8), response: response, installed: installed, now: now)
    }

    @Test func comparesNumericReleaseTagsAndLinksToThatRelease() throws {
        let body = #"{"tag_name":"v0.10.2"}"#
        let newer = try result(body, installed: "0.9.12")
        #expect(newer.status == .available)
        #expect(newer.latest == "0.10.2")
        #expect(newer.url.absoluteString == "https://github.com/dc-orz/GlassNotes/releases/tag/v0.10.2")
        #expect(try result(body, installed: "0.10.2").status == .upToDate)
        #expect(try result(body, installed: "1.0").status == .upToDate)
        #expect(try result(#"{"tag_name":"1.0.0"}"#, installed: "1").status == .upToDate)
        #expect(try result(body, installed: nil).status == .unknownInstalledVersion)
    }

    @Test func failuresKeepTheirReason() {
        #expect(throws: ReleaseCheck.Failure.noRelease) { try result("", installed: "1", http: 404) }
        #expect(throws: ReleaseCheck.Failure.http(503)) { try result("", installed: "1", http: 503) }
        #expect(throws: ReleaseCheck.Failure.rateLimited(until: now.addingTimeInterval(300))) {
            try result(
                "", installed: "1", http: 403,
                headers: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1300"])
        }
        #expect(throws: ReleaseCheck.Failure.rateLimited(until: now.addingTimeInterval(90))) {
            try result(
                "", installed: "1", http: 403, headers: ["Retry-After": "90", "X-RateLimit-Remaining": "42"])
        }
        #expect(throws: ReleaseCheck.Failure.rateLimited(until: now.addingTimeInterval(60))) {
            try result(#"{"message":"You have exceeded a secondary rate limit."}"#, installed: "1", http: 403)
        }
        #expect(throws: ReleaseCheck.Failure.http(403)) { try result("", installed: "1", http: 403) }
        for body in ["{}", #"{"tag_name":"v1..1"}"#, #"{"tag_name":"v"}"#] {
            #expect(throws: ReleaseCheck.Failure.invalidResponse) { try result(body, installed: "1") }
        }
    }

    @Test func offersOnlyVerifiedPackagesForANewerCompatibleRelease() throws {
        let hash = String(repeating: "1a", count: 32)
        let data = Data(
            """
            {"tag_name":"v0.2","assets":[
              {"name":"GlassNotes-0.2-x86_64.dmg","digest":"sha256:bad"},
              {"name":"GlassNotes-0.2-arm64.dmg.sha256"},
              {"name":"GlassNotes-0.1-x86_64.dmg","digest":"sha256:\(hash)"},
              {"name":"GlassNotes-0.2-arm64.dmg","digest":"sha256:\(hash)"}
            ]}
            """.utf8)
        let response = try #require(
            HTTPURLResponse(url: URL(fileURLWithPath: "/"), statusCode: 200, httpVersion: nil, headerFields: nil))
        func check(_ installed: String?, _ architecture: MacArchitecture) throws -> ReleasePackage? {
            try ReleaseCheck.result(
                data: data, response: response, installed: installed, architecture: architecture
            ).package
        }
        let package = try #require(try check("0.1", .arm64))
        #expect(
            package.url.absoluteString
                == "https://github.com/dc-orz/GlassNotes/releases/download/v0.2/GlassNotes-0.2-arm64.dmg")
        #expect(package.sha256 == hash)
        #expect(try check("0.1", .intel) == nil)
        #expect(try check("0.2", .arm64) == nil)
        #expect(try check(nil, .arm64) == nil)
    }

    @Test func reopeningDuringRateLimitSkipsTheNetwork() async throws {
        let check = ReleaseCheck()
        let reset = Int(Date.now.timeIntervalSince1970) + 120
        let limit = ReleaseCheck.Failure.rateLimited(until: Date(timeIntervalSince1970: TimeInterval(reset)))
        await confirmation(expectedCount: 1) { fetched in
            for _ in 0..<2 {
                await #expect(throws: limit) {
                    try await check.latest { request in
                        fetched()
                        let url = try #require(request.url)
                        let response = try #require(
                            HTTPURLResponse(
                                url: url, statusCode: 429, httpVersion: nil,
                                headerFields: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": String(reset)]))
                        return (Data(), response)
                    }
                }
            }
        }
    }
}
