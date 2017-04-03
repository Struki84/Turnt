//
//  Config.swift
//  TurntChat
//
//  Created by Šimun on 15.07.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import Foundation

class ConfigManager {
    
    static let sharedInstance = ConfigManager()
    
    var isDev: Bool?
    var paidApp: Bool?
    var maxAllowedAccounts: Int?
    var data: Dictionary<String, AnyObject>? = Dictionary()
    var testFriends: [Dictionary<String, AnyObject>] = []
    var alertMsg: Dictionary<String, String>!
    
    var apiKey: String?
    var apiUrl: String?
    var WebSocketUrl: String?
    var hashToken: String?
    
    
    init(){
        if let path = Bundle.main.path(forResource: "ApplicationData", ofType: "plist") {
            if let data = NSDictionary(contentsOfFile: path) as? Dictionary<String, AnyObject> {
                self.isDev = data["Development"] as? Bool
                self.testFriends = (data["TestFriendsSearch"] as? [Dictionary<String, AnyObject>])!
                self.alertMsg = (data["AlertMsgs"] as? Dictionary<String, String>)!
                
                if (self.isDev! == true) {
                    if let configData = data["Config"] as? Dictionary<String, AnyObject> {
                        self.data = configData["Development"] as? Dictionary<String, AnyObject>
                        self.paidApp = self.data!["PaidApp"] as! Bool?
                        self.maxAllowedAccounts = self.data!["MaxAllowedAccounts"] as! Int?
                        self.apiUrl = self.data!["ApiUrl"] as! String?
                        self.apiKey = self.data!["ApiKey"] as! String?
                        self.WebSocketUrl = self.data!["SocketURL"] as! String?
                    }
                }
                else {
                    if let configData = data["Config"] as? Dictionary<String, AnyObject> {
                        self.data = configData["Production"] as? Dictionary<String, AnyObject>
                    }
                }
            }
        }
    }    
}
