//
//  File.swift
//  
//
//  Created by Willy on 2024/3/28.
//

import Foundation
import Vapor

class FCMConfigManager {
    static let shared = FCMConfigManager()
    
    private init() { }
    
    // MARK: Firebase Auth Json
    var email = ""
    var projectID = ""
    var key = ""
}
