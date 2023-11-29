//
//  NewsAPIEnum.swift
//  ColorBarTesting
//
//  Created by ZHIWEI XU on 2023/4/4.
//

import Foundation

enum urlType: String {
    case search
    case topics
    case article
    
    func getPrefixPath() -> String {
        switch self {
        case .search:
            return "/search"
        case .topics:
            return "/topics"
        case .article:
            return "/article"
        }
    }
}

enum Category: String, CaseIterable, Codable {
    case general
    case business
    case technology
    case entertainment
    case sports
    case health
    
    var chineseName: String {
        switch self {
        case .business:
            return "商業"
        case .entertainment:
            return "娛樂"
        case .general:
            return "一般"
        case .health:
            return "健康"
        case .sports:
            return "體育"
        case .technology:
            return "科技"
        }
    }
    
    var order: Int {
        switch self {
        case .general:
            return 0
        case .business:
            return 1
        case .health:
            return 2
        case .technology:
            return 3
        case .sports:
            return 5
        case .entertainment:
            return 6
        }
    }
    
    static func getTotal() -> Int {
        return Category.allCases.count
    }
    
    static func fromOrder(_ order: Int) -> Category? {
        return Category.allCases.first(where: { $0.order == order })
    }
}

enum CountryCode: String, CaseIterable, Codable {
    case BR // 巴西
    case CN // 中國
    case DE // 德國
    case FR // 法國
    case GB // 英國
    case IN // 印度
    case TW // 意大利
    case JP // 日本
    case MX // 墨西哥
    case US // 美國
    case none = ""
    
    var chineseName: String {
        switch self {
        case .BR:
            return "巴西"
        case .CN:
            return "中國"
        case .DE:
            return "德國"
        case .FR:
            return "法國"
        case .GB:
            return "英國"
        case .IN:
            return "印度"
        case .TW:
            return "台灣"
        case .JP:
            return "日本"
        case .MX:
            return "墨西哥"
        case .US:
            return "美國"
        case .none:
            return "未選擇"
        }
    }
    
    func getPath() -> String {
        switch self {
        case .BR:
            "hl=pt-BR&gl=BR&ceid=BR:pt-419"
        case .CN:
            "hl=zh-CN&gl=CN&ceid=CN:zh-Hans"
        case .DE:
            "hl=de&gl=DE&ceid=DE:de"
        case .FR:
            "hl=fr&gl=FR&ceid=FR:fr"
        case .GB:
            "hl=en-GB&gl=GB&ceid=GB:en"
        case .IN:
            "hl=en-IN&gl=IN&ceid=IN:en"
        case .TW:
            "hl=zh-TW&gl=TW&ceid=TW:zh-Hant"
        case .JP:
            "hl=ja&gl=JP&ceid=JP:ja"
        case .MX:
            "hl=es-419&gl=MX&ceid=MX:es-419"
        case .US:
            "hl=en-US&gl=US&ceid=US:en"
        case .none:
            ""
        }
    }
}

enum SearchIn: String, Codable {
    case title
    case description
    case content
    case all = "title,content,description"
    
    var chineseName: String {
        switch self {
        case .title:
            return "標題"
        case .description:
            return "簡述"
        case .content:
            return "內容"
        case .all:
            return "全部內容"
        }
    }
}

enum SearchSortBy: String, Codable {
    case relevancy
    case popularity
    case publishedAt
    
    var chineseName: String {
        switch self {
        case .relevancy:
            return "相關度"
        case .popularity:
            return "熱門排序"
        case .publishedAt:
            return "最新排序"
        }
    }
}

enum DisplayMode: String {
    case headline
    case search
}

enum SearchLanguage: String, CaseIterable, Codable {
    case zh
    case ar
    case de
    case en
    case es
    case fr
    case hi
    case it
    case nl
    case no
    case pt
    case ru
    case sv
    case ur

    var chineseName: String {
        switch self {
        case .zh:
            return "中文"
        case .ar:
            return "阿拉伯語"
        case .de:
            return "德語"
        case .en:
            return "英語"
        case .es:
            return "西班牙語"
        case .fr:
            return "法語"
        case .hi:
            return "印地語"
        case .it:
            return "意大利語"
        case .nl:
            return "荷蘭語"
        case .no:
            return "挪威語"
        case .pt:
            return "葡萄牙語"
        case .ru:
            return "俄語"
        case .sv:
            return "瑞典語"
        case .ur:
            return "烏爾都語"
        }
    }
}
