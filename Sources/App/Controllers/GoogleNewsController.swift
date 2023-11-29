//
//  File.swift
//  
//
//  Created by Willy on 2023/11/27.
//

import Vapor
import SwiftSoup

struct GoogleNewsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let newsRoute = routes.grouped("googlenews")
        newsRoute.get(use: scrapeGoogleNews)
    }

    func scrapeGoogleNews(req: Request) async throws -> NewsAPIResponse {
        
        let queryParameters = try req.query.decode(NewsQueryParameters.self)
        
        guard let type = urlType(rawValue: queryParameters.type),
              let country = CountryCode(rawValue: queryParameters.country) else {
            return NewsAPIResponse(status: "N", totalResults: 0, articles: [])
        }
        
        // MARK: - Get Data URL And Check Defualt Articles Data
        var url = ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        
        switch type {
        case .topics:
            guard let categoryStr = queryParameters.category, let category = Category(rawValue: categoryStr) else {
                return NewsAPIResponse(status: "N", totalResults: 0, articles: [])
            }
            
            // MARK: - 時間內返回預存資料
            if let defualtArticlesTuple = newsManager.categoryArticles[country]?[category],
               let defualtDate = formatter.date(from: defualtArticlesTuple.date),
               Date.now < defualtDate.addingTimeInterval(600) {
                let articles = defualtArticlesTuple.articles
                let apiResponse = NewsAPIResponse(status: "OK", totalResults: articles.count, articles: articles)
                
                return apiResponse
            }
            
            // MARK: - 取得Topics網址path
            if newsManager.topicsPathDic[category] == nil {
                _ = try await updateNewsCategory(req: req)
            }
            
            url = newsManager.getUrl(type: type, country: country, category: category)
        case .search:
            let queryString = queryParameters.q
            url = newsManager.getUrl(type: type, country: country, q: queryString)
        default:
            return NewsAPIResponse(status: "N", totalResults: 0, articles: [])
        }
        
        
        /// Prepare Data
        var articles = [Article]()
        
        // 使用 Vapor 的 client 發送 HTTP 請求
        let result = try await req.client.get(URI(string: url))

        guard result.status == .ok else {
            throw Abort(.internalServerError, reason: "無法獲取 Google News 的資訊")
        }
        
        guard let body = result.body, let html = body.getString(at: body.readerIndex, length: body.readableBytes) else {
            throw Abort(.internalServerError, reason: "無法讀取 HTML 內容")
        }

        // 使用 SwiftSoup 解析 HTML
        let document = try SwiftSoup.parse(html)
        
        _ = try document.getElementsByTag("article").map { e in
            let title = try e.text()
            let publishedAt = try e.getElementsByTag("time").first()?.text() ?? ""
            let source = Source(id: "", name: try e.getElementsByAttribute("data-n-tid").first()?.text() ?? "")
            let author = try e.getElementsByAttribute("data-n-tid").first()?.text() ?? ""
            var url = try e.getElementsByAttribute("target").first()?.getAttributes()?.get(key: "href") ?? ""
            if !url.contains("http") && url.contains("./") {
                url.replace("./", with: e.getBaseUri())
            }
            let imageUrl = try e.getElementsByClass("Quavad").first()?.getAttributes()?.get(key: "src")
            
            let article = Article(source: source, author: author, title: title, description: nil, url: url, urlToImage: imageUrl, publishedAt: publishedAt, content: nil)
            
            articles.append(article)
        }
        
        // MARK: - Topics 回存預設資料
        if type == .topics,
            let categoryStr = queryParameters.category,
            let category = Category(rawValue: categoryStr) {
            if newsManager.categoryArticles[country] == nil {
                newsManager.categoryArticles[country] = [:]
            }
            newsManager.categoryArticles[country]?[category] = (date: formatter.string(from: Date.now), articles: articles)
        }
        
        let apiResponse = NewsAPIResponse(status: "OK", totalResults: articles.count, articles: articles)
        
        return apiResponse
    }
    
    
    // MARK: - 取得Topics網址path
    func updateNewsCategory(req: Request) async throws -> ClientResponse {
        let url = "\(newsManager.homeUrl)?\(CountryCode.TW.getPath())"
        let result = try await req.client.get(URI(string: url))
        guard result.status == .ok else {
            throw Abort(.internalServerError, reason: "無法獲取 Google News 的資訊")
        }

        // 解析 HTML 內容
        guard let body = result.body, let html = body.getString(at: body.readerIndex, length: body.readableBytes) else {
            throw Abort(.internalServerError, reason: "無法讀取 HTML 內容")
        }
        
        var categoryPathArr = [(category: String, path: String)]()
        
        // 使用 SwiftSoup 解析 HTML
        let document = try SwiftSoup.parse(html)
        
        _ = try document.getElementsByAttributeValueContaining("role", "menuitem").map { e in
            let role = try e.attr("role")
            guard e.tag().getName() == "a",
                  try e.attr("href").contains("topics") else {
                return
            }
            
            let path = try e.attr("href").replacing("./topics", with: "").split(separator: "?").first

            categoryPathArr.append((try e.text(), String(path ?? "path Error")))
        }
        
        // MARK: - 移除兩項(國際, 當地)分類
        categoryPathArr.remove(at: 1)
        categoryPathArr.remove(at: 1)
        
        for i in 0 ..< categoryPathArr.count {
            let data = categoryPathArr[i]
            let category = Category.allCases[i]
            newsManager.topicsPathDic[category] = data.path
        }
        
        return result
    }
}
