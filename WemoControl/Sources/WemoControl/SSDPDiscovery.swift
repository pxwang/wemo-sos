import Foundation
import Darwin

enum SSDPDiscovery {
    /// Sends an SSDP M-SEARCH to the multicast address and collects unicast
    /// LOCATION replies from Wemo devices on the local network. No cloud
    /// involved — this is a pure LAN broadcast/response.
    static func discover(timeout: TimeInterval = 4) -> [URL] {
        var locationStrings = Set<String>()

        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return [] }
        defer { close(sock) }

        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var tv = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(1900).bigEndian
        addr.sin_addr.s_addr = inet_addr("239.255.255.250")

        let message =
            "M-SEARCH * HTTP/1.1\r\n" +
            "HOST: 239.255.255.250:1900\r\n" +
            "MAN: \"ssdp:discover\"\r\n" +
            "MX: 3\r\n" +
            "ST: urn:Belkin:device:**\r\n\r\n"
        let payload = [UInt8](message.utf8)

        let sent = withUnsafePointer(to: &addr) { ptr -> Int in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                sendto(sock, payload, payload.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard sent > 0 else { return [] }

        let deadline = Date().addingTimeInterval(timeout)
        var buffer = [UInt8](repeating: 0, count: 4096)
        while Date() < deadline {
            let n = recv(sock, &buffer, buffer.count, 0)
            if n > 0 {
                let text = String(decoding: buffer[0..<n], as: UTF8.self)
                if let loc = extractLocation(from: text) {
                    locationStrings.insert(loc)
                }
            }
        }
        return locationStrings.compactMap { URL(string: $0) }
    }

    private static func extractLocation(from text: String) -> String? {
        for rawLine in text.split(separator: "\r\n") {
            let line = String(rawLine)
            if line.lowercased().hasPrefix("location:") {
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
