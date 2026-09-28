import Foundation

struct WemoDevice: Hashable {
    let location: URL
    var friendlyName: String
    var modelName: String
    var isOn: Bool
}

enum WemoError: Error {
    case badControlURL
}

enum WemoClient {
    static func fetchDescription(location: URL) async -> (name: String, model: String) {
        guard let (data, _) = try? await URLSession.shared.data(from: location) else {
            return ("Wemo Device", "?")
        }
        let xml = String(decoding: data, as: UTF8.self)
        let name = firstMatch(pattern: "<friendlyName>(.*?)</friendlyName>", in: xml) ?? "Wemo Device"
        let model = firstMatch(pattern: "<modelName>(.*?)</modelName>", in: xml) ?? "?"
        return (name, model)
    }

    static func getBinaryState(location: URL) async -> Bool {
        guard let resp = try? await soapRequest(location: location, action: "GetBinaryState", bodyInner: "") else {
            return false
        }
        return firstMatch(pattern: "<BinaryState>(\\d+)</BinaryState>", in: resp) == "1"
    }

    @discardableResult
    static func setBinaryState(location: URL, on: Bool) async -> Bool {
        let inner = "<BinaryState>\(on ? 1 : 0)</BinaryState>"
        _ = try? await soapRequest(location: location, action: "SetBinaryState", bodyInner: inner)
        return on
    }

    private static func controlURL(for location: URL) -> URL? {
        guard let host = location.host else { return nil }
        var comps = URLComponents()
        comps.scheme = "http"
        comps.host = host
        comps.port = location.port
        comps.path = "/upnp/control/basicevent1"
        return comps.url
    }

    private static func soapRequest(location: URL, action: String, bodyInner: String) async throws -> String {
        guard let url = controlURL(for: location) else { throw WemoError.badControlURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"urn:Belkin:service:basicevent:1#\(action)\"", forHTTPHeaderField: "SOAPAction")

        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
        <u:\(action) xmlns:u="urn:Belkin:service:basicevent:1">\(bodyInner)</u:\(action)>
        </s:Body></s:Envelope>
        """
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return String(decoding: data, as: UTF8.self)
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
