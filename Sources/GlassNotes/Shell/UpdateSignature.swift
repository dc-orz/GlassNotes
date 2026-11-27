import Foundation
import Security

enum UpdateSignature {
    static func verify(_ candidate: URL, replacing installed: URL) throws {
        let original = try staticCode(at: installed)
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(original, [], &information) == errSecSuccess,
            let flags = (information as NSDictionary?)?[kSecCodeInfoFlags] as? UInt32
        else { throw UpdateInstaller.Failure.signature }

        // Ad hoc builds have a different code hash at every release. Their origin is
        // authenticated by the repository's HTTPS release metadata and asset digest.
        var requirement: SecRequirement?
        if !SecCodeSignatureFlags(rawValue: flags).contains(.adhoc) {
            guard SecCodeCopyDesignatedRequirement(original, [], &requirement) == errSecSuccess,
                requirement != nil
            else { throw UpdateInstaller.Failure.signature }
        }
        let checks = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        guard SecStaticCodeCheckValidity(try staticCode(at: candidate), checks, requirement) == errSecSuccess
        else { throw UpdateInstaller.Failure.signature }
    }

    private static func staticCode(at url: URL) throws -> SecStaticCode {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code
        else { throw UpdateInstaller.Failure.signature }
        return code
    }
}
