import Hummingbird
import Mustache
import Foundation
let library = try await MustacheLibrary(directory: "Resources")

let router = Router()
router.get("/get-udid.mobileconfig") { request, _ -> String in
    let requestUUID = UUID().uuidString
    let mobileconfig = library.render([
        "uuid": requestUUID,
    ], withTemplate: "get-udid.mobileconfig")
    return mobileconfig ?? String("abject failure")
}
// create application using router
let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
// run hummingbird application
try await app.runService()
