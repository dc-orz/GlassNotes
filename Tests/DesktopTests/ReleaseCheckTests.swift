import Foundation
import Testing

@testable import GlassNotes

struct ReleaseCheckTests {
    private func result(_ body: String, installed: String?, http: Int = 200, headers: [String: String]? = nil)
        throws -> ReleaseCheck.Result
    {
        let response = try #require(
            HTTPURLResponse(
                url: URL(fileURLWithPath: "/"), statusCode: http, httpVersion: "HTTP/1.1", headerFields: headers))
        return try ReleaseCheck.result(data: Data(body.utf8), response: response, installed: installed)
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
        #expect(throws: ReleaseCheck.Failure.rateLimited) {
            try result("", installed: "1", http: 403, headers: ["X-RateLimit-Remaining": "0"])
        }
        #expect(throws: ReleaseCheck.Failure.rateLimited) {
            try result(
                "", installed: "1", http: 403, headers: ["Retry-After": "60", "X-RateLimit-Remaining": "42"])
        }
        #expect(throws: ReleaseCheck.Failure.http(403)) { try result("", installed: "1", http: 403) }
        for body in ["{}", #"{"tag_name":"v1..1"}"#, #"{"tag_name":"v"}"#] {
            #expect(throws: ReleaseCheck.Failure.invalidResponse) { try result(body, installed: "1") }
        }
    }
}
