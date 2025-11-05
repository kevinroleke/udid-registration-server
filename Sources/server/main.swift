import Hummingbird
import Mustache
let library = try await MustacheLibrary(directory: "Resources")

let router = Router()
router.get("profile") { request, _ -> String in
    return "Hello"
}
// create application using router
let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
// run hummingbird application
try await app.runService()
