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

let router = Router()
router.get("/get-udid.mobileconfig") { request, _ -> String in
    let requestUUID = UUID().uuidString
    let mobileconfig = library.render([
        "uuid": requestUUID,
        "server": "https://udid.zerogon.consulting",
    ], withTemplate: "get-udid.mobileconfig")
    return mobileconfig ?? String("abject failure")
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
