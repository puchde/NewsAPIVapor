//
//  File.swift
//  
//
//  Created by Willy on 2023/11/28.
//

import Foundation
import Vapor
import SwiftSoup

class NewsConfigManager {
    static let shared = NewsConfigManager()
    private init() { }
    
    var baseUrl = "https://news.google.com"
    var baseRssUrl = "https://news.google.com/rss"
    var homeUrl = "https://news.google.com/home"
    
    var topicsPathDic = [Category: String]()
    var topicsRegionPathDic = [CountryCode: String]()
    
    // MARK: - Cache Key
    func getKey(isProtobuf: Bool, country: CountryCode, category: Category, isNotification: Bool) -> String {
        var key = isProtobuf ? "Protobuf+" : ""
        key += "\(urlType.topics.rawValue)+\(country.rawValue)+\(category.rawValue)"
        if isNotification {
            key += "+Notificaiton"
        }
        return key
    }
    
    func getKey(isProtobuf: Bool, country: CountryCode, queryString: String, searchTime: String) -> String {
        var key = isProtobuf ? "Protobuf+" : ""
        key += "\(urlType.search.rawValue)+\(country.rawValue)+\(queryString)+\(searchTime)"
        return key
    }
}

// MARK: - Get API Type URL
extension NewsConfigManager {
    func getUrl(type: urlType, country: CountryCode, category: Category? = nil, q: String? = nil, qSearchTime: String? = nil, isRss: Bool = false) -> String {
        var url = ""
        let baseUrl = isRss ? baseRssUrl : baseUrl
        switch type {
        case .search:
            /// https://news.google.com/search?q=taiwan&hl=zh-TW&gl=TW&ceid=TW%3Azh-Hant
            ///
            var q = q ?? ""
            let qSearchTime = qSearchTime ?? ""
            if !qSearchTime.isEmpty {
                q += " when:\(qSearchTime)"                
            }
            guard let q = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return "error"
            }
            
            url = "\(baseUrl)\(type.getPrefixPath())?q=\(String(describing: q))&\(country.getPath())"
        case .topics:
            /// "https://news.google.com/topics/CAAqLAgKIiZDQkFTRmdvSkwyMHZNR1ptZHpWbUVnVjZhQzFVVnhvQ1ZGY29BQVAB?hl=zh-TW&gl=TW&ceid=TW%3Azh-Hant"
            ///
            guard let category = category, let topicsPath = topicsPathDic[category], let regionPath = topicsRegionPathDic[country] else {
                return "error"
            }
            let path = category == .general ? regionPath : topicsPath
            url = "\(baseUrl)\(type.getPrefixPath())\(String(describing: path))?\(country.getPath())"
        case .article:
            break
        }
        
        return url
    }

}
