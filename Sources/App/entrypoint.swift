import Vapor
import Dispatch
import Logging

var app: Application!
var appCache = app.cache

var newsManager = NewsConfigManager.shared
var fcmManager = FCMConfigManager.shared

/// This extension is temporary and can be removed once Vapor gets this support.
private extension Vapor.Application {
    static let baseExecutionQueue = DispatchQueue(label: "vapor.codes.entrypoint")
    
    func runFromAsyncMainEntrypoint() async throws {
        try await withCheckedThrowingContinuation { continuation in
            Vapor.Application.baseExecutionQueue.async { [self] in
                do {
                    try self.run()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        app = Application(env)
        defer { app.shutdown() }
        
        do {
            app.caches.use(.memory)
            try await configure(app)
        } catch {
            app.logger.report(error: error)
            throw error
        }
        try await app.runFromAsyncMainEntrypoint()
    }
}
