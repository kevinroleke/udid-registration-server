import Hummingbird
import Mustache
import Foundation
let library = try await MustacheLibrary(directory: "Resources")

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
// create application using router
let app = Application(
    router: router,
    configuration: .init(address: .hostname("localhost", port: 8080))
)
// run hummingbird application
try await app.runService()
