import Hummingbird
import Mustache
import Foundation
import DotEnv
let library = try await MustacheLibrary(directory: "Resources")
let path = ".env"
var env = try DotEnv.load(path: path)
print(env)
let apiKey = ProcessInfo.processInfo.environment["APPLE_API_KEY"]!
let issuerID = ProcessInfo.processInfo.environment["APPLE_ISSUER_ID"]!
let serverUrl = ProcessInfo.processInfo.environment["SERVER_URL"]!
let signerPath = ProcessInfo.processInfo.environment["SIGNER_PATH"]!
let privKeyPath = ProcessInfo.processInfo.environment["PRIVKEY_PATH"]!
let certFilePath = ProcessInfo.processInfo.environment["CERTFILE_PATH"]!
let openSSLPath = ProcessInfo.processInfo.environment["OPENSSL_PATH"]!

struct HTML: ResponseGenerator {
    let html: String

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let buffer = ByteBuffer(string: self.html)
        return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
    }
}

struct Device: Codable {
    let id: String
    let name: String
    let platform: String
}

func createJWT(apiKey: String, issuerID: String) -> String {
    // Generate JWT token here (this requires a library like JWTKit or similar)
    return "your_jwt_token"
}

func addDevice(name: String, platform: String) {
    let url = URL(string: "https://api.appstoreconnect.apple.com/v1/devices")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(createJWT(apiKey: apiKey, issuerID: issuerID))", forHTTPHeaderField: "Authorization")

    let device = Device(id: UUID().uuidString, name: name, platform: platform)
    do {
        let jsonData = try JSONEncoder().encode(["data": ["type": "devices", "attributes": ""]])
        request.httpBody = jsonData
    } catch {
        print("Error encoding device data: \(error)")
        return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error adding device: \(error.localizedDescription)")
            return
        }
        guard let data = data else {
            print("No data received")
            return
        }

        do {
            let responseObject = try JSONDecoder().decode(Device.self, from: data)
            print("Device added: \(responseObject)")
        } catch {
            print("Error decoding response: \(error)")
        }
    }

    task.resume()
}

func signMobileConfig(mobileconfig: String) throws -> Hummingbird.ByteBuffer {
    let fileManager = FileManager.default
    let randomUUID = UUID().uuidString
    let url = URL( fileURLWithPath: "./Temp/\(randomUUID)" )
    let signedURL = URL( fileURLWithPath: "./Temp/\(randomUUID).signed" )

    try mobileconfig.write(to: url, atomically: true, encoding: .utf8)

    let task = Process()

    task.arguments = ["smime", "-sign", "-in", "./Temp/\(randomUUID)",
  "-out", "./Temp/\(randomUUID).signed",
  "-signer", signerPath,
  "-inkey", privKeyPath,
  "-certfile", certFilePath,
  "-outform", "der", "-nodetach"]
    task.launchPath = openSSLPath
    task.standardInput = nil
    try task.run()
    task.waitUntilExit()

    let buf = Hummingbird.ByteBuffer(data: try Data(contentsOf: signedURL) )

    try fileManager.removeItem(at: signedURL)
    try fileManager.removeItem(at: url)

    return buf
}

let router = Router()
router.get("/get-udid.mobileconfig") { request, _ -> Hummingbird.ByteBuffer in
    let requestUUID = UUID().uuidString
    let mobileconfig = library.render([
        "uuid": requestUUID,
        "server": serverUrl,
    ], withTemplate: "get-udid.mobileconfig")

    return try! signMobileConfig(mobileconfig: mobileconfig!)
}
router.post("/register-udid/:uuid") { req, ctx async throws -> Response in
    let uuid = try ctx.parameters.require("uuid", as: String.self)
    var buf = Hummingbird.ByteBuffer()
    try await req.body.collect(upTo: 10000, into: &buf)
    print(uuid)
    print(buf)
    do {
        let s: String? = buf.getString(at: 64, length: 380, encoding: .utf8)
        let fs = s?.split(separator: "<key>UDID</key>\n\t<string>")
        if fs?.count ?? 0 < 2 {
            throw HTTPError(.badRequest, message: "Fuck you")
        }
        let udid = fs?[1].split(separator: "</string>")
        if udid?.count ?? 0 < 1 {
            throw HTTPError(.badRequest, message: "Fuck you")
        }
        return Response.redirect(to: "\(serverUrl)/apply-udid/\(udid![0])", type: .permanent)
    } catch {
        throw HTTPError(.badRequest, message: "Fuck you")
    }
}
router.get("/apply-udid/:udid") { request, ctx throws -> String in
    let udid = try ctx.parameters.require("udid", as: String.self)
    return udid
}
router.get("/") { request, ctx -> HTML in
    return HTML(html: library.render([], withTemplate: "index") ?? String("abject failure"))
}
// create application using router
let app = Application(
    router: router,
    configuration: .init(address: .hostname("localhost", port: 8080))
)
// run hummingbird application
try await app.runService()
