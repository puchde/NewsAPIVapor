//
//  File.swift
//  
//
//  Created by Willy on 2023/11/27.
//

import Vapor
import SwiftSoup
import SwiftProtobuf

struct GoogleNewsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let newsRoute = routes.grouped("googlenews")
        newsRoute.get(use: scrapeGoogleNews)
        newsRoute.get("update", use: updateCategoryArticles)
        newsRoute.post("protobuf", use: scrapeGoogleNewsProtobuf)
    }

    func scrapeGoogleNews(req: Request) async throws -> NewsAPIResponse {
        
        let queryParameters = try req.query.decode(NewsQueryParameters.self)
        
        guard let type = urlType(rawValue: queryParameters.type),
              let country = CountryCode(rawValue: queryParameters.country) else {
            return NewsAPIResponse(status: "N", totalResults: 0, articles: [])
        }
        
        // MARK: - Get Data URL And Check Defualt Articles Data
        var url = ""
        var cacheKey = "\(type)+\(country)"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        
        switch type {
        case .topics:
            guard let categoryStr = queryParameters.category, let category = Category(rawValue: categoryStr) else {
                return NewsAPIResponse(status: "N", totalResults: 0, articles: [])
            }
            
            cacheKey += "+\(categoryStr)"
            
            // MARK: - 取得Topics網址path
            if newsManager.topicsPathDic[category] == nil {
                _ = try await updateNewsCategory(req: req)
            }
            
            url = newsManager.getUrl(type: type, country: country, category: category)
        case .search:
            let queryString = queryParameters.q
            cacheKey += "+\(String(describing: queryString))"
            url = newsManager.getUrl(type: type, country: country, q: queryString)
        default:
            return NewsAPIResponse(status: "N", totalResults: 0, articles: [])
        }
        
        
        // MARK: - 時間內返回Cache預存資料
        if let cacheArticles = try await appCache.get(cacheKey, as: NewsAPIResponse.self) {
            print("cache item memory: \(MemoryLayout.size(ofValue: cacheArticles))")
            print("cache return")
            return cacheArticles
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
            var title = try e.getElementsByTag("a").filter{a in try !a.text().isEmpty}.first?.text() ?? ""
            let publishedAt = try e.getElementsByTag("time").first()?.text() ?? ""
            let source = Source(id: "", name: try e.getElementsByAttribute("data-n-tid").first()?.text() ?? "")
            let author = try e.getElementsByAttribute("data-n-tid").first()?.text() ?? ""
            var url = try e.getElementsByAttribute("target").first()?.getAttributes()?.get(key: "href") ?? ""
            if !url.contains("http") && url.contains("./") {
                url.replace("./", with: e.getBaseUri())
            }
            let imageUrl = try e.getElementsByClass("Quavad").first()?.getAttributes()?.get(key: "src")
            
            let article = Article(source: source, author: author, title: title, description: "", url: url, urlToImage: imageUrl, publishedAt: publishedAt, content: "")
            
            articles.append(article)
        }
        
        let apiResponse = NewsAPIResponse(status: "OK", totalResults: articles.count, articles: articles)
        
        // MARK: - 回存Cache資料
        try await appCache.set(cacheKey, to: apiResponse, expiresIn: .minutes(22))
        print("item memory: \(MemoryLayout.size(ofValue: apiResponse))")
        return apiResponse
    }
    
    func scrapeGoogleNewsProtobuf(req: Request) async throws -> NewsAPIProtobufResponse {
        
        let queryParameters = try req.query.decode(NewsQueryParameters.self)
        
        guard let type = urlType(rawValue: queryParameters.type),
              let country = CountryCode(rawValue: queryParameters.country) else {
            app.logger.info("Type Error: \(String(describing: queryParameters.type)),\n Country Error: \(String(describing: queryParameters.country))")
            return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
        }
        
        // MARK: - Get Data URL And Check Defualt Articles Data
        var url = ""
        var cacheKey = "Protobuf+\(type)+\(country)"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        
        switch type {
        case .topics:
            guard let categoryStr = queryParameters.category, let category = Category(rawValue: categoryStr) else {
                app.logger.info("Category Error: \(queryParameters.category ?? "Not Para")")
                return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
            }
            
            cacheKey += "+\(categoryStr)"
            
            // MARK: - 取得Topics網址path
            if newsManager.topicsPathDic[category] == nil {
                _ = try await updateNewsCategory(req: req)
            }
            
            url = newsManager.getUrl(type: type, country: country, category: category)
        case .search:
            let queryString = queryParameters.q
            cacheKey += "+\(String(describing: queryString))"
            url = newsManager.getUrl(type: type, country: country, q: queryString)
        default:
            return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
        }
        
        
        // MARK: - 時間內返回Cache預存資料
        if let cacheArticles = try await appCache.get(cacheKey, as: NewsAPIProtobufResponse.self) {
            print("cache item memory: \(MemoryLayout.size(ofValue: cacheArticles))")
            print("cache return")
            return cacheArticles
        }
        
        let apiProtobufResponse = await getNewsData(req: req, url: url, cacheKey: cacheKey)
        
        // MARK: - 回存Cache資料
        try await appCache.set(cacheKey, to: apiProtobufResponse, expiresIn: .minutes(22))
        print("item memory: \(MemoryLayout.size(ofValue: apiProtobufResponse))")
        return apiProtobufResponse
    }
}

extension GoogleNewsController {
    // MARK: - Update地區Topic
    func updateCategoryArticles(req: Request) async throws -> Response {
        let queryParameters = try req.query.decode(NewsUpdateQueryParameters.self)
        
        if let country = CountryCode(rawValue: queryParameters.country) {
            for category in Category.allCases {
                if newsManager.topicsPathDic[category] == nil {
                    _ = try await updateNewsCategory(req: req)
                }
                let url = newsManager.getUrl(type: .topics, country: country, category: category)
                print(url)
                Task {
                    let cacheKey = "Protobuf+\(urlType.topics)+\(country)+\(category)"
                    print(cacheKey)
                    _ = await getNewsData(req: req, url: url, cacheKey: cacheKey)
                }
            }
        } else {
            for country in CountryCode.allCases {
                for category in Category.allCases {
                    if newsManager.topicsPathDic[category] == nil {
                        _ = try await updateNewsCategory(req: req)
                    }
                    let url = newsManager.getUrl(type: .topics, country: country, category: category)
                    print(url)
                    Task {
                        let cacheKey = "Protobuf+\(urlType.topics)+\(country)+\(category)"
                        print(cacheKey)
                        _ = await getNewsData(req: req, url: url, cacheKey: cacheKey)
                    }
                }
            }
        }
        return Response(body: "UPDATE")
    }
}

extension GoogleNewsController {
    // MARK: - 取得News (Category & Search)
    func getNewsData(req: Request, url: String, cacheKey: String) async -> NewsAPIProtobufResponse {
        do {
            /// Prepare Data
            var articleProtobufs: [ArticleProtobuf] = []
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
                var title = try e.getElementsByTag("a").filter{a in try !a.text().isEmpty}.first?.text() ?? ""
                let publishedAt = try e.getElementsByTag("time").first()?.text() ?? ""
                let source = Source(id: "", name: try e.getElementsByAttribute("data-n-tid").first()?.text() ?? "")
                let author = try e.getElementsByAttribute("data-n-tid").first()?.text() ?? ""
                var url = try e.getElementsByAttribute("target").first()?.getAttributes()?.get(key: "href") ?? ""
                if !url.contains("http") && url.contains("./") {
                    url.replace("./", with: e.getBaseUri())
                }
                let imageUrl = try e.getElementsByClass("Quavad").first()?.getAttributes()?.get(key: "src")
                
                //
                let sourceProtobuf = try SourceProtobuf.with {
                    $0.id = ""
                    $0.name = try e.getElementsByAttribute("data-n-tid").first()?.text() ?? ""
                }
                
                let articleProtobuf = ArticleProtobuf.with {
                    $0.source = sourceProtobuf
                    $0.author = author
                    $0.title = title
                    $0.url = url
                    $0.urlToImage = imageUrl ?? ""
                    $0.publishedAt = publishedAt
                }
                articleProtobufs.append(articleProtobuf)
            }
            
            let articlesTotalProtobuf = ArticlesTotalProtobuf.with {
                $0.articles = articleProtobufs
                $0.totalResults = Int32(articleProtobufs.count)
            }
            let articlesData = try articlesTotalProtobuf.serializedData()

            
            let apiProtobufResponse = NewsAPIProtobufResponse(status: "OK", totalResults: articleProtobufs.count, articles: articlesData)
            try await appCache.set(cacheKey, to: apiProtobufResponse, expiresIn: .minutes(20))
            print("cacheOK: \(cacheKey)")
            return apiProtobufResponse
        } catch {
            print(error)
            return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
        }
    }

}

extension GoogleNewsController {
    // MARK: - 取得Topics網址path
    func updateNewsCategory(req: Request) async throws -> Void {
        for country in CountryCode.allCases {
            let url = "\(newsManager.homeUrl)?\(country.getPath())"
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
            
            if country == .TW {
                for i in 0 ..< categoryPathArr.count {
                    let data = categoryPathArr[i]
                    let category = Category.allCases[i]
                    newsManager.topicsPathDic[category] = data.path
                }
                
                // 固定Path
                newsManager.topicsPathDic[Category.science] = Category.science.getTopicPath()
            }
            let data = categoryPathArr[0]
            newsManager.topicsRegionPathDic[country] = data.path
        }
        app.logger.info("Get General Path Finished")
        return
    }
}
