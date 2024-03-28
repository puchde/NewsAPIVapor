//
//  File.swift
//  
//
//  Created by Willy on 2024/3/28.
//

import Foundation
import Vapor

// MARK: SimpleMessage Response
struct SimpleResponse: Content {
    let isSuccess: Bool
    let message: String
}
