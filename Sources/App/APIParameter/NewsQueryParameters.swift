//
//  File.swift
//  
//
//  Created by Willy on 2023/11/29.
//

import Foundation
import Vapor

struct NewsQueryParameters: Content {
    var type: String  // Assuming urlType is a String
    var country: String  // Assuming CountryCode is a String
    var category: String?  // Assuming Category is a String
    var q: String?
    var searchTime: String?
}

struct NewsUpdateQueryParameters: Content {
    var country: String  // Assuming CountryCode is a String
}
