//
//  NewsAPIResponse.swift
//  ColorBarTesting
//
//  Created by ZHIWEI XU on 2023/4/3.
//

import Foundation
import Vapor

// MARK: everything API, Headlines API
struct NewsAPIResponse: Content {
    let status: String
    let totalResults: Int
    let articles: [Article]
}

struct Article: Content {
    static func == (lhs: Article, rhs: Article) -> Bool {
        lhs.url == rhs.url
    }

    let source: Source
    let author: String?
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let content: String?
}

struct Source: Content {
    let id: String?
    let name: String
}


struct NewsAPIProtobufResponse: Content {
    let status: String
    let totalResults: Int
    let articles: Data
}

//MARK: - Title
struct NewsTitleResponse: Content {
    let status: String
    let totalResults: Int
    let articles: [NewsTitleObject]
}

struct NewsTitleObject: Content, Codable {
    let title: String
    let url: String
}
