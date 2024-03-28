import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    let googleNewsController = GoogleNewsController()
    try app.register(collection: googleNewsController)
    
    let firebaseViewController = FirebaseViewController()
    try app.register(collection: firebaseViewController)
}
