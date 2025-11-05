import Hummingbird
import Mustache
import Foundation
let library = try await MustacheLibrary(directory: "Resources")

struct HTML: ResponseGenerator {
    let html: String

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let buffer = ByteBuffer(string: self.html)
        return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
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
  "-signer", "../your-pub-cert.pem",
  "-inkey", "../your-priv-key.pem",
  "-certfile", "../your_cert.pem",
  "-outform", "der", "-nodetach"]
    task.launchPath = "/opt/homebrew/bin/openssl"
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
        "server": "https://udid.zerogon.consulting",
    ], withTemplate: "get-udid.mobileconfig")

    return try! signMobileConfig(mobileconfig: mobileconfig!)
}
router.get("/register-udid/:uuid") { request, ctx -> String in
    let uuid = try ctx.parameters.require("uuid", as: String.self)
    print(uuid)
    return uuid
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
