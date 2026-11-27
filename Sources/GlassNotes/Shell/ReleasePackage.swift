import Foundation

enum MacArchitecture: String {
    case arm64
    case intel = "x86_64"

    static var current: Self {
        #if arch(arm64)
            return .arm64
        #else
            var translated: Int32 = 0
            var size = MemoryLayout.size(ofValue: translated)
            sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0)
            return translated == 1 ? .arm64 : .intel
        #endif
    }

    var executableArchitecture: Int {
        self == .arm64 ? NSBundleExecutableArchitectureARM64 : NSBundleExecutableArchitectureX86_64
    }
}

struct ReleasePackage {
    struct Asset: Decodable {
        let name: String
        let digest: String?
    }

    let version: String
    let url: URL
    let sha256: String

    static func select(from assets: [Asset], version: String, tag: String, architecture: MacArchitecture) -> Self?
    {
        for suffix in [architecture.rawValue, "arm64-x86_64", "x86_64-arm64"] {
            let name = "GlassNotes-\(version)-\(suffix).dmg"
            guard let asset = assets.first(where: { $0.name == name }),
                let digest = asset.digest, digest.hasPrefix("sha256:")
            else { continue }
            let hash = digest.dropFirst("sha256:".count).lowercased()
            guard hash.utf8.count == 64,
                hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
            else { continue }
            let url = URL(string: "https://github.com/dc-orz/GlassNotes/releases/download/")!
                .appendingPathComponent(tag).appendingPathComponent(name)
            return Self(version: version, url: url, sha256: hash)
        }
        return nil
    }
}
