import Darwin
import Foundation

/// One request and one response per connection. EOF in each direction delimits its JSON document.
package final class CommandSocket: Sendable {
    package let handle: FileHandle

    package init(descriptor: Int32) throws {
        guard descriptor >= 0 else { throw Self.systemError() }
        handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0, fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK) == 0,
            fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0
        else { throw Self.systemError() }
        var enabled: Int32 = 1
        var timeout = timeval(tv_sec: 10, tv_usec: 0)
        guard
            setsockopt(
                descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout.size(ofValue: enabled)))
                == 0,
            setsockopt(
                descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
                == 0,
            setsockopt(
                descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout))) == 0
        else { throw Self.systemError() }
    }

    package static func path(for pid: pid_t) throws -> String {
        // A shell and a Launch Services app may have different TMPDIR environment variables.
        let size = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
        guard size > 0 else { throw systemError() }
        var buffer = [CChar](repeating: 0, count: size)
        guard confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, size) == size else { throw systemError() }
        let directory = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        return URL(fileURLWithPath: directory).appendingPathComponent("glassnotes-\(pid).sock").path
    }

    package static func withAddress<T>(_ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T)
        throws -> T
    {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let bytes = path.utf8CString
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw POSIXError(.ENAMETOOLONG) }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes.map { UInt8(bitPattern: $0) }) }
        return try withUnsafePointer(to: &address) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }

    package func send(_ data: Data) throws {
        try handle.write(contentsOf: data)
        guard shutdown(handle.fileDescriptor, SHUT_WR) == 0 else { throw Self.systemError() }
    }

    package func receive(limit: Int = .max) throws -> Data {
        var result = Data()
        while let bytes = try handle.read(upToCount: 64 * 1024), !bytes.isEmpty {
            guard bytes.count <= limit - result.count else { throw POSIXError(.EMSGSIZE) }
            result.append(bytes)
        }
        return result
    }

    package static func systemError() -> POSIXError { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}
