import Hummingbird
import Mustache
import Foundation
import DotEnv
import JWTKit
import CryptoKit

let library = try await MustacheLibrary(directory: "Resources")

let path = ".env"
try DotEnv.load(path: path)

let apiKey = ProcessInfo.processInfo.environment["APPLE_API_KEY"]!
let issuerID = ProcessInfo.processInfo.environment["APPLE_ISSUER_ID"]!
let authKeyPath = ProcessInfo.processInfo.environment["APPLE_AUTHKEY_PATH"]!
let serverUrl = ProcessInfo.processInfo.environment["SERVER_URL"]!
let signerPath = ProcessInfo.processInfo.environment["SIGNER_PATH"]!
let privKeyPath = ProcessInfo.processInfo.environment["PRIVKEY_PATH"]!
let certFilePath = ProcessInfo.processInfo.environment["CERTFILE_PATH"]!
let openSSLPath = ProcessInfo.processInfo.environment["OPENSSL_PATH"]!
let finalURL = ProcessInfo.processInfo.environment["FINAL_URL"]!

let authKey = try String(contentsOf: URL(filePath: authKeyPath), encoding: .utf8)
let trimmedKey = authKey
        .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
        .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
        .replacingOccurrences(of: "\n", with: "")
print(trimmedKey)

let key = try JWTKit.ES256PrivateKey(pem: authKey)
let keys = JWTKeyCollection()
await keys.add(ecdsa: key, kid: JWKIdentifier(string: apiKey))

struct DeviceAttributes: Codable {
    let udid: String
    let name: String
    let platform: String
}

struct DeviceData: Codable {
    let type: String
    let attributes: DeviceAttributes
}

struct DeviceRequest: Codable {
    let data: DeviceData
}

struct HTML: ResponseGenerator {
    let html: String

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let buffer = ByteBuffer(string: self.html)
        return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
    }
}

struct MyJWT: JWTPayload {
    var exp: ExpirationClaim
    var iss: IssuerClaim
    var aud: AudienceClaim
    var iat: IssuedAtClaim

    init(issuerId: String) {
        self.exp = ExpirationClaim(value: Date().addingTimeInterval(20 * 60))
        self.iat = IssuedAtClaim(value: Date())
        self.iss = IssuerClaim(value: issuerId)
        self.aud = AudienceClaim(value: "appstoreconnect-v1")
    }

    func verify(using key: some JWTAlgorithm) throws {
        try self.exp.verifyNotExpired()
    }
}

func createJWT(appleKeyId: String, issuerId: String) async -> String? {
    do {

        let payload = MyJWT(issuerId: issuerId)
        let jwt = try await keys.sign(payload, header: JWTHeader(fields: ["kid": JWTHeaderField(stringLiteral: appleKeyId)]))
        return jwt
    } catch {
        print("Error signing JWT: \(error)")
        return nil
    }
}

func addDevice(name: String, platform: String, udid: String) async -> Bool {
    let url = URL(string: "https://api.appstoreconnect.apple.com/v1/devices")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    guard let jwtToken = await createJWT(appleKeyId: apiKey, issuerId: issuerID) else {
        return false
    }
    print(jwtToken)

    request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
    let attributes = DeviceAttributes(udid: udid, name: name, platform: platform)
    let deviceData = DeviceData(type: "devices", attributes: attributes)
    let deviceRequest = DeviceRequest(data: deviceData)

    do {
        let jsonData = try JSONEncoder().encode(deviceRequest)
        request.httpBody = jsonData
    } catch {
        print("Error encoding device data: \(error)")
        return false
    }

    do {
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
            return true
        } else {
            print("Unexpected response: \(String(describing: response))")
            return false
        }
    } catch {
        print("API request error: \(error)")
        return false
    }
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
        return Response.redirect(to: "\(serverUrl)/apply-udid/\(udid![0])/\(uuid)", type: .permanent)
    } catch {
        throw HTTPError(.badRequest, message: "Fuck you")
    }
}
router.get("/apply-udid/:udid/:uuid") { request, ctx async throws -> Response in
    let udid = try ctx.parameters.require("udid", as: String.self)
    let uuid = try ctx.parameters.require("uuid", as: String.self)
    let suc = await addDevice(name: uuid, platform: "IOS", udid: udid)
    if suc {
        return Response.redirect(to: finalURL)
    }
    return Response.redirect(to: "\(serverUrl)/error")
}
router.get("/") { request, ctx -> HTML in
    return HTML(html: library.render([], withTemplate: "index") ?? String("abject failure"))
}
router.get("/error") { _, _ -> String in
    return "There was an error"
}
// create application using router
let app = Application(
    router: router,
    configuration: .init(address: .hostname("localhost", port: 8080))
)
// run hummingbird application
try await app.runService()
