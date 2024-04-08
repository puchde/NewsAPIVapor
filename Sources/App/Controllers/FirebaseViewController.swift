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

        guard let country = CountryCode(rawValue: queryParameters.country) else {
            return SimpleResponse(isSuccess: false, message: "Category Error")
        }
        
        let categorys = Category.allCases
        categorys.forEach { category in
            let cacheKey = newsManager.getKey(isProtobuf: true, country: country, category: category, isNotification: true)
            guard let cache = try? appCache.get(cacheKey, as: [NewsTitleObject].self).wait(),
                  let news = cache.randomElement() else {
                return
            }

            let condition = "'\(country.rawValue)' in topics && '\(category.rawValue)' in topics"
            let notification = FCMNotification(title: "Get Snapper", body: news.title)
            let data = ["url": "\(news.url)"]
            let message = FCMMessage(condition: condition, notification: notification, data: data)
            _ = req.fcm.send(message, on: req.eventLoop)
        }
        
        // 使用 Vapor 的 client 發送 HTTP 請求
        return SimpleResponse(isSuccess: true, message: "")
    }
}
