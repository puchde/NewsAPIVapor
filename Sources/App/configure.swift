import Vapor
import FCM

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.fcm.configuration = .init(email: fcmManager.email, projectId: fcmManager.projectID, key: fcmManager.key)
    
    // register routes
    try routes(app)
}
