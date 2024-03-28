//
//  FirebaseViewController.swift.swift
//
//
//  Created by Willy on 2024/3/27.
//

import Vapor
import FCM

struct FirebaseViewController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let newsRoute = routes.grouped("fcm")
        newsRoute.post(use: sendMessage)
    }
}

extension FirebaseViewController {
    func sendMessage(req: Request) async throws -> SimpleResponse {
        let queryParameters = try req.query.decode(FCMQueryParameter.self)

        guard let category = Category(rawValue: queryParameters.category) else {
            return SimpleResponse(isSuccess: false, message: "Category Error")
        }
        
        let notification = FCMNotification(title: "Vapor is awesome!", body: "Swift one love! ❤️")
        let message = FCMMessage(topic: category.rawValue, notification: notification)
        let result = req.fcm.send(message, on: req.eventLoop)
        result.map { str in
            print(str)
        }
        
        // 使用 Vapor 的 client 發送 HTTP 請求
        return SimpleResponse(isSuccess: true, message: "")
    }
}
