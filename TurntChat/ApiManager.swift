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
    let apiBaseUrl: NSURL?
    var apiEndpoint: NSURL?
    var request: NSMutableURLRequest?
    
    var responseString: String?
    var responseJson: JSON = "{}"
    var HTTPResponseCode: Int?
    var success: Bool?
    
    func _handleSuccess(data: NSData){
        self.responseString = NSString(data: data, encoding: NSUTF8StringEncoding) as? String
        self.responseJson = JSON(data: data)
        self.success = true
    }
    
    func _handleFailure(data: NSData){
        self.success = false
        self.responseString = NSString(data: data, encoding: NSUTF8StringEncoding) as? String
    }
    
    init(){
        #if TARGET_IPHONE_SIMULATOR
            self.deviceId = "BCB52548-A80E-4CA2-87CE-66D23675FEEE";
        #else
            self.deviceId = UIDevice.currentDevice().identifierForVendor!.UUIDString
        #endif
        self.apiBaseUrl = NSURL(string:ConfigManager.sharedInstance.apiUrl!)
        
        if(ConfigManager.sharedInstance.hashToken == nil) {
            self.authorizationToken = "apiKey=\(self.deviceId!)"
        } else {
            self.authorizationToken = "FIRE-TOKEN hash=\(ConfigManager.sharedInstance.hashToken!), apiKey=\(self.deviceId!)"
        }
    }
    
    func sendRequest(link: String, HTTPMethod: String, requestBody: JSON?, completion:(success: Bool) -> ()){
        
        self.apiEndpoint = NSURL(string: link, relativeToURL: self.apiBaseUrl)
        self.request = NSMutableURLRequest(URL: self.apiEndpoint!)
        self.request!.HTTPMethod = HTTPMethod
        self.request!.addValue("application/json", forHTTPHeaderField: "Content-Type")
        self.request!.addValue(self.authorizationToken!, forHTTPHeaderField: "Authorization")
        let jsonData: NSData = requestBody!.stringValue.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        self.request?.HTTPBody = jsonData
        
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(self.request!, completionHandler: {responseBody, responseHeaders, error -> Void in
            if error == nil {
                if let HTTPResponse = responseHeaders as? NSHTTPURLResponse {
                    self.HTTPResponseCode = HTTPResponse.statusCode
                    if HTTPResponse.statusCode == 200 {
//                        print("Server respondes OK!")
                        dispatch_async(dispatch_get_main_queue()) {
                            self._handleSuccess(responseBody!)
                            completion(success: self.success!)
                        }
                    }
                    else {
                        dispatch_async(dispatch_get_main_queue()) {
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
    
    func sendRequest(link: String, HTTPMethod: String, requestBody: [String : String]? = nil, completion:(success: Bool) -> ()){
        
        if(ConfigManager.sharedInstance.hashToken == nil) {
            self.authorizationToken = "apiKey=\(self.deviceId!)"
        } else {
            self.authorizationToken = "FIRE-TOKEN hash=\(ConfigManager.sharedInstance.hashToken!), apiKey=\(self.deviceId!)"
        }
        
        self.apiEndpoint = NSURL(string: link, relativeToURL: self.apiBaseUrl)
        self.request = NSMutableURLRequest(URL: self.apiEndpoint!)
        self.request!.HTTPMethod = HTTPMethod
        self.request!.addValue("application/json", forHTTPHeaderField: "Content-Type")
        self.request!.addValue(self.authorizationToken!, forHTTPHeaderField: "Authorization")
//        print("Request Body: \(requestBody)")
//        print("Token in sendRequest: \(self.authorizationToken!)")
        if let _ = requestBody {
            let request: AnyObject = requestBody as! AnyObject
            self.request!.HTTPBody = try? NSJSONSerialization.dataWithJSONObject(request, options: [])
        }
        
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(self.request!, completionHandler: {responseBody, responseHeaders, error -> Void in
            if error == nil {
                if let HTTPResponse = responseHeaders as? NSHTTPURLResponse {
                    self.HTTPResponseCode = HTTPResponse.statusCode
                    if HTTPResponse.statusCode == 200 {
//                        print("Server respondes OK!")
                        dispatch_async(dispatch_get_main_queue()) {
                            self._handleSuccess(responseBody!)
                            completion(success: self.success!)
                        }
                    }
                    else {
                        print("Server respondes \(self.HTTPResponseCode)")
                        dispatch_async(dispatch_get_main_queue()) {
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