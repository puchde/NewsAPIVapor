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
    var rssDateFormatter: DateFormatter {
        let rssDateFormatter = DateFormatter()
        rssDateFormatter.dateFormat = "EEE',' dd MMM yyyy HH:mm:ss' GMT'"
        rssDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        rssDateFormatter.timeZone = TimeZone(identifier: "GMT")
        return rssDateFormatter
    }
    
    var transformDateFormatter: DateFormatter {
        let transformDateFormatter = DateFormatter()
        transformDateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        // TODO: 時區固定待APP端同時實作
        return transformDateFormatter
    }
    
    func boot(routes: RoutesBuilder) throws {
        let newsRoute = routes.grouped("googlenews")
        newsRoute.post(use: scrapeGoogleNews)
        newsRoute.post("protobuf", use: scrapeGoogleNewsProtobuf)
        newsRoute.get("update", use: updateCategoryArticles)
    }
}

extension GoogleNewsController {
    // MARK: - base
    func scrapeGoogleNews(req: Request) async throws -> NewsAPIResponse {
        
        let queryParameters = try req.query.decode(NewsQueryParameters.self)
        
        guard let type = urlType(rawValue: queryParameters.type),
              let country = CountryCode(rawValue: queryParameters.country) else {
            return NewsAPIResponse(status: "N", totalResults: 0, articles: [])
        }
        
        // MARK: - Get Data URL And Check Defualt Articles Data
        var url = ""
        var cacheKey = ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        
        switch type {
        case .topics:
            guard let categoryStr = queryParameters.category, let category = Category(rawValue: categoryStr) else {
                return NewsAPIResponse(status: "N", totalResults: 0, articles: [])
            }
            
            cacheKey = newsManager.getKey(isProtobuf: false, country: country, category: category, isNotification: false)
            
            // MARK: - 取得Topics網址path
            if newsManager.topicsPathDic[category] == nil {
                _ = try await updateNewsCategory(req: req)
            }
            
            url = newsManager.getUrl(type: type, country: country, category: category)
        case .search:
            let queryString = queryParameters.q
            let searchTime = queryParameters.searchTime ?? ""
            cacheKey = newsManager.getKey(isProtobuf: false, country: country, queryString: String(describing: queryString), searchTime: searchTime)
            url = newsManager.getUrl(type: type, country: country, q: queryString, qSearchTime: searchTime)
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
            var imagePath = try e.getElementsByClass("Quavad").first()?.getAttributes()?.get(key: "src") ?? ""
            if !imagePath.isEmpty && !imagePath.contains("http") {
                imagePath = newsManager.baseUrl + imagePath
            }

            let article = Article(source: source, author: author, title: title, description: "", url: url, urlToImage: imagePath, publishedAt: publishedAt, content: "")
            
            articles.append(article)
        }
        
        let apiResponse = NewsAPIResponse(status: "OK", totalResults: articles.count, articles: articles)
        
        print("item memory: \(MemoryLayout.size(ofValue: apiResponse))")
        return apiResponse
    }
    
    // MARK: - base/protobuf
    func scrapeGoogleNewsProtobuf(req: Request) async throws -> NewsAPIProtobufResponse {
        
        let queryParameters = try req.query.decode(NewsQueryParameters.self)
        
        guard let type = urlType(rawValue: queryParameters.type),
              let country = CountryCode(rawValue: queryParameters.country) else {
            print("Type Error: \(String(describing: queryParameters.type)),\n Country Error: \(String(describing: queryParameters.country))")
            return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
        }
        
        // MARK: - Get Data URL And Check Defualt Articles Data
        var url = ""
        var cacheKey = ""
        var notificationCacheKey = ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"

        // For Search
        let searchSort = SearchSortBy(rawValue: queryParameters.searchSort ?? "") ?? SearchSortBy.none
        
        switch type {
        case .topics:
            guard let categoryStr = queryParameters.category, let category = Category(rawValue: categoryStr) else {
                print("Category Error: \(queryParameters.category ?? "Not Para")")
                return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
            }
            cacheKey = newsManager.getKey(isProtobuf: true, country: country, category: category, isNotification: false)
            notificationCacheKey = newsManager.getKey(isProtobuf: true, country: country, category: category, isNotification: true)
            
            // MARK: - 取得Topics網址path
            if newsManager.topicsPathDic[category] == nil {
                _ = try await updateNewsCategory(req: req)
            }
            
            url = newsManager.getUrl(type: type, country: country, category: category)
        case .search:
            let queryString = queryParameters.q ?? ""
            let searchTime = queryParameters.searchTime ?? ""
            cacheKey = newsManager.getKey(isProtobuf: true, country: country, queryString: String(describing: queryString), searchTime: searchTime)
            url = newsManager.getUrl(type: type, country: country, q: queryString, qSearchTime: searchTime, isRss: true)
        default:
            return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
        }
        
        
        // MARK: - 時間內返回Cache預存資料
        if let cacheArticles = try await appCache.get(cacheKey, as: NewsAPIProtobufResponse.self) {
            print("cache return, cache Key: \(cacheKey)")
            if type == .search {
                return sortNews(response: cacheArticles, searchSort: searchSort)
            } else {
                return cacheArticles
            }
        }
        
        let apiProtobufResponse = await {
            switch type {
            case .search:
                let data = await getNewsDataRss(req: req, url: url, cacheKey: cacheKey)
                return sortNews(response: data, searchSort: searchSort)
            case .topics:
                return await getNewsData(req: req, url: url, cacheKey: cacheKey, notificationCacheKey: notificationCacheKey)
            default:
                return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
            }
        }()
        
        print("scrape return")
        return apiProtobufResponse
    }
    
    // MARK: - base/Update - 更新地區Topic
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
                    let cacheKey = newsManager.getKey(isProtobuf: true, country: country, category: category, isNotification: false)
                    let notificationCacheKey = newsManager.getKey(isProtobuf: true, country: country, category: category, isNotification: true)
                    print("update: \(cacheKey)")
                    _ = await getNewsData(req: req, url: url, cacheKey: cacheKey, notificationCacheKey: notificationCacheKey)
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
                        let cacheKey = newsManager.getKey(isProtobuf: true, country: country, category: category, isNotification: false)
                        let notificationCacheKey = newsManager.getKey(isProtobuf: true, country: country, category: category, isNotification: true)
                        print("update: \(cacheKey)")
                        _ = await getNewsData(req: req, url: url, cacheKey: cacheKey, notificationCacheKey: notificationCacheKey)
                    }
                }
            }
        }
        return Response(body: "UPDATE")
    }
}

// MARK: - 取得News (Category & Search)
extension GoogleNewsController {
    func getNewsData(req: Request, url: String, cacheKey: String, notificationCacheKey: String) async -> NewsAPIProtobufResponse {
        do {
            /// FCM
            var notificationNews: [NewsTitleObject] = []
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
                var imagePath = try e.getElementsByClass("Quavad").first()?.getAttributes()?.get(key: "src") ?? ""
                if !imagePath.isEmpty && !imagePath.contains("http") {
                    imagePath = newsManager.baseUrl + imagePath
                }
                
                notificationNews.append(NewsTitleObject(title: title, url: url))
                
                // Protobuf
                let sourceProtobuf = try SourceProtobuf.with {
                    $0.id = ""
                    $0.name = try e.getElementsByAttribute("data-n-tid").first()?.text() ?? ""
                }
                
                let articleProtobuf = ArticleProtobuf.with {
                    $0.source = sourceProtobuf
                    $0.author = author
                    $0.title = title
                    $0.url = url
                    $0.urlToImage = imagePath
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
            try await appCache.set(cacheKey, to: apiProtobufResponse, expiresIn: .seconds(1190))
            try await appCache.set(notificationCacheKey, to: notificationNews, expiresIn: .seconds(1190))
            print("cacheOK: \(cacheKey)")
            return apiProtobufResponse
        } catch {
            print(error)
            return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
        }
    }
    
    func getNewsDataRss(req: Request, url: String, cacheKey: String) async -> NewsAPIProtobufResponse {
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
            let document = try SwiftSoup.parse(html, html, Parser.xmlParser())
            _ = try document.select("item").map({ e in
                var titleO = try e.getElementsByTag("title").text().split(separator: " - ")
                titleO.remove(at: titleO.count - 1)
                var title = ""
                for t in titleO {
                    title += t
                }
                let url = try e.getElementsByTag("link").text()
                
                let publishedStr = String(try e.getElementsByTag("pubdate").text())
                let publishDate = rssDateFormatter.date(from: String(publishedStr))
                let publishedAt = transformDateFormatter.string(from: publishDate ?? Date())
                
                let author = try e.getElementsByTag("source").text()
                                
                let sourceProtobuf = try SourceProtobuf.with {
                    $0.id = ""
                    $0.name = try e.getElementsByTag("source").text()
                }
                
                let articleProtobuf = ArticleProtobuf.with {
                    $0.source = sourceProtobuf
                    $0.author = author
                    $0.title = title
                    $0.url = url
                    $0.urlToImage = ""
                    $0.publishedAt = publishedAt
                }
                articleProtobufs.append(articleProtobuf)
            })
            
            let articlesTotalProtobuf = ArticlesTotalProtobuf.with {
                $0.articles = articleProtobufs
                $0.totalResults = Int32(articleProtobufs.count)
            }
            let articlesData = try articlesTotalProtobuf.serializedData()
            
            let apiProtobufResponse = NewsAPIProtobufResponse(status: "OK", totalResults: articleProtobufs.count, articles: articlesData)
            try await appCache.set(cacheKey, to: apiProtobufResponse, expiresIn: .seconds(1190))
            print("cacheOK: \(cacheKey)")
            return apiProtobufResponse
        } catch {
            print(error)
            return NewsAPIProtobufResponse(status: "N", totalResults: 0, articles: Data())
        }
    }
}

// MARK: - Search Sort
extension GoogleNewsController {
    func sortNews(response: NewsAPIProtobufResponse, searchSort: SearchSortBy) -> NewsAPIProtobufResponse {
        do {
            switch searchSort {
            case .relevancy:
                break
            case .popularity:
                break
            case .publishedAt:
                var articlesTotals = try ArticlesTotalProtobuf(serializedData: response.articles)
                articlesTotals.articles.sort { a, b in
                    return transformDateFormatter.date(from: a.publishedAt) ?? .now > transformDateFormatter.date(from: b.publishedAt) ?? .now
                }
                let articles = try articlesTotals.serializedData()
                return NewsAPIProtobufResponse(status: response.status, totalResults: response.totalResults, articles: articles)
            case .none:
                break
            }
        } catch {
            print(error)
        }
        return response
    }
}

// MARK: - 首次取得Topics網址path
extension GoogleNewsController {
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
            
            if country == .US {
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
        print("Get General Path Finished")
        return
    }
}
