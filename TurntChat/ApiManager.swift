//
//  ApiManager.swift
//  CommunicationTest
//
//  Created by Šimun on 26.04.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON


class ApiManager {
//Set all server data in stored plist file
//Add request struct for storing abstract request based on plist urls
//Server creates account without providing username

    var apiVars: NSDictionary?
    
    let deviceId: String?
    var authorizationToken: String?
    let apiBaseUrl: URL?
    var apiEndpoint: URL?
    var request: NSMutableURLRequest?
    
    var responseString: String?
    var responseJson: JSON = "{}"
    var HTTPResponseCode: Int?
    var success: Bool?
    
    func _handleSuccess(_ data: Data){
        self.responseString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String
        self.responseJson = JSON(data: data)
        self.success = true
    }
    
    func _handleFailure(_ data: Data){
        self.success = false
        self.responseString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String
    }
    
    init(){
        #if TARGET_IPHONE_SIMULATOR
            self.deviceId = "BCB52548-A80E-4CA2-87CE-66D23675FEEE";
        #else
            self.deviceId = UIDevice.current.identifierForVendor!.uuidString
        #endif
        self.apiBaseUrl = URL(string:ConfigManager.sharedInstance.apiUrl!)
        
        if(ConfigManager.sharedInstance.hashToken == nil) {
            self.authorizationToken = "apiKey=\(self.deviceId!)"
        } else {
            self.authorizationToken = "FIRE-TOKEN hash=\(ConfigManager.sharedInstance.hashToken!), apiKey=\(self.deviceId!)"
        }
    }
    
    func sendRequest(_ link: String, HTTPMethod: String, requestBody: JSON?, completion:@escaping (_ success: Bool) -> ()){
        
        self.apiEndpoint = URL(string: link, relativeTo: self.apiBaseUrl)
        self.request = NSMutableURLRequest(url: self.apiEndpoint!)
        self.request!.httpMethod = HTTPMethod
        self.request!.addValue("application/json", forHTTPHeaderField: "Content-Type")
        self.request!.addValue(self.authorizationToken!, forHTTPHeaderField: "Authorization")
        let jsonData: Data = requestBody!.stringValue.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        self.request?.httpBody = jsonData
        
        let session = URLSession.shared
        let task = session.dataTask(with: self.request!, completionHandler: {responseBody, responseHeaders, error -> Void in
            if error == nil {
                if let HTTPResponse = responseHeaders as? HTTPURLResponse {
                    self.HTTPResponseCode = HTTPResponse.statusCode
                    if HTTPResponse.statusCode == 200 {
//                        print("Server respondes OK!")
                        DispatchQueue.main.async {
                            self._handleSuccess(responseBody!)
                            completion(success: self.success!)
                        }
                    }
                    else {
                        DispatchQueue.main.async {
                            self._handleFailure(responseBody!)
                            completion(success: self.success!)
                        }
                    }
                }
            }
            else {
                print("Task error: \(error!.localizedDescription)")
            }

        })
        task.resume()
    }
    
    func sendRequest(_ link: String, HTTPMethod: String, requestBody: [String : String]? = nil, completion:@escaping (_ success: Bool) -> ()){
        
        if(ConfigManager.sharedInstance.hashToken == nil) {
            self.authorizationToken = "apiKey=\(self.deviceId!)"
        } else {
            self.authorizationToken = "FIRE-TOKEN hash=\(ConfigManager.sharedInstance.hashToken!), apiKey=\(self.deviceId!)"
        }
        
        self.apiEndpoint = URL(string: link, relativeTo: self.apiBaseUrl)
        self.request = NSMutableURLRequest(url: self.apiEndpoint!)
        self.request!.httpMethod = HTTPMethod
        self.request!.addValue("application/json", forHTTPHeaderField: "Content-Type")
        self.request!.addValue(self.authorizationToken!, forHTTPHeaderField: "Authorization")
//        print("Request Body: \(requestBody)")
//        print("Token in sendRequest: \(self.authorizationToken!)")
        if let _ = requestBody {
            let request: AnyObject = requestBody as AnyObject
            self.request!.httpBody = try? JSONSerialization.data(withJSONObject: request, options: [])
        }
        
        let session = URLSession.shared
        let task = session.dataTask(with: self.request!, completionHandler: {responseBody, responseHeaders, error -> Void in
            if error == nil {
                if let HTTPResponse = responseHeaders as? HTTPURLResponse {
                    self.HTTPResponseCode = HTTPResponse.statusCode
                    if HTTPResponse.statusCode == 200 {
//                        print("Server respondes OK!")
                        DispatchQueue.main.async {
                            self._handleSuccess(responseBody!)
                            completion(success: self.success!)
                        }
                    }
                    else {
                        print("Server respondes \(self.HTTPResponseCode)")
                        DispatchQueue.main.async {
                            self._handleFailure(responseBody!)
                            completion(success: self.success!)
                        }
                    }
                }
            }
            else {
                print("Task error: \(error!.localizedDescription)")
            }
            
        })
        task.resume()
    }
}
