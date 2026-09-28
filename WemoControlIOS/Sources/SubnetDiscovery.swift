import Foundation
import Darwin

/// iOS blocks raw IP multicast (SSDP) for apps without Apple's Multicast
/// Networking entitlement, which requires a paid developer account and a
/// separate approval from Apple. This works around it by unicast-probing
/// every host on the local /24 subnet for the Wemo setup.xml endpoint —
/// unicast HTTP only needs the standard Local Network permission.
enum SubnetDiscovery {
    private static let candidatePorts = [49153, 49152, 49154]

    static func scan() async -> [WemoDevice] {
        guard let ip = localWiFiIPv4(), let base = subnetBase(from: ip) else { return [] }
        let selfLastOctet = Int(ip.split(separator: ".").last ?? "") ?? -1

        var results: [WemoDevice] = []
        await withTaskGroup(of: WemoDevice?.self) { group in
            var launched = 0
            for host in 1...254 {
                if host == selfLastOctet { continue }
                for port in candidatePorts {
                    group.addTask { await probe(host: "\(base).\(host)", port: port) }
                    launched += 1
                    if launched % 64 == 0 {
                        if let found = await group.next(), let device = found {
                            results.append(device)
                        }
                    }
                }
            }
            for await found in group {
                if let device = found {
                    results.append(device)
                }
            }
        }
        return results
    }

    private static func probe(host: String, port: Int) async -> WemoDevice? {
        guard let url = URL(string: "http://\(host):\(port)/setup.xml") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let xml = String(decoding: data, as: UTF8.self)
        guard xml.contains("Belkin") else { return nil }

        let name = firstMatch(pattern: "<friendlyName>(.*?)</friendlyName>", in: xml) ?? "Wemo Device"
        let model = firstMatch(pattern: "<modelName>(.*?)</modelName>", in: xml) ?? "?"
        let isOn = await WemoClient.getBinaryState(location: url)
        return WemoDevice(location: url, friendlyName: name, modelName: model, isOn: isOn)
    }

    private static func localWiFiIPv4() -> String? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let interface = current.pointee
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
               String(cString: interface.ifa_name) == "en0" {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                return String(cString: hostname)
            }
            ptr = interface.ifa_next
        }
        return nil
    }

    private static func subnetBase(from ip: String) -> String? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let r = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[r])
    }
}
