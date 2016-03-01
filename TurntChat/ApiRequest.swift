//
//  ApiRequest.swift
//  CommTest
//
//  Created by Šimun on 02.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import Foundation
import SwiftyJSON


class ApiRequest: ApiManager {
    
    override init(){
        super.init()
    }
    
//MARK: - Custom Requests
    
    func login(requestBody: [String : String], completionHandler: (success: Bool, logedIn: Bool?, responseBody: JSON, error: Int?) -> Void) {
        let link = "login"
        let HTTPMethod = "POST"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, requestBody:requestBody , completion: {(requestSuccessfull) in
            var logedIn: Bool? = nil
            let error = self.responseJson["error"].int
            if requestSuccessfull {
               logedIn = self.responseJson["logedIn"].bool
            }
            completionHandler(success:requestSuccessfull, logedIn:logedIn, responseBody: self.responseJson, error: error)
        })
    }
    
    func recoveryAccount(requestBody: [String: String], completionHandler: (success: Bool, logedIn: Bool?, responseBody: JSON, error: Int?) -> Void) {
        let link = "account/recovery"
        let HTTPMethod = "POST"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, requestBody:requestBody , completion: {(requestSuccessfull) in
            var logedIn: Bool? = nil
            let error = self.responseJson["error"].int
            if requestSuccessfull {
                logedIn = self.responseJson["logedIn"].bool
            }
            completionHandler(success:requestSuccessfull, logedIn:logedIn, responseBody: self.responseJson, error: error)
        })
    }
    
    func createAccount(requestBody: [String: String], completionHandler:(success: Bool, accountCreated: Bool?, userAccounts: JSON!, responseBody: JSON, error: Int?) -> Void) {
        let link = "account/save/"
        let HTTPMethod = "POST"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, requestBody: requestBody, completion: {(requestSuccessfull) in
            var accountCreated: Bool?
            var userAccounts: JSON!
            let error = self.responseJson["error"].int
            if self.success! {
                accountCreated = self.responseJson["accountCreated"].bool
                userAccounts = self.responseJson["userAccounts"]
            }
            completionHandler(success: requestSuccessfull, accountCreated: accountCreated, userAccounts:userAccounts , responseBody: self.responseJson, error: error)
        })
    }

    func updateAccount(requestBody: [String : String], completionHandler:(success: Bool, accountUpdated: Bool?, userAccount: JSON!, responseBody: JSON, error: Int?) -> Void) {
        let link = "account/save/\(requestBody["account_id"]!)"
        let HTTPMethod = "POST"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, requestBody: requestBody, completion: { (requestSuccessfull) in
            var accountUpdated: Bool?
            var userAccount: JSON!
            let error = self.responseJson["error"].int
            if self.success! {
                accountUpdated = self.responseJson["accountCreated"].bool
                userAccount = self.responseJson["account"]
            }
            completionHandler(success: requestSuccessfull, accountUpdated: accountUpdated, userAccount: userAccount, responseBody: self.responseJson, error: error)
        })
    }

    func getAccounts(completionHandler: (success: Bool, accounts: JSON, error: Int?) -> Void) {
        let link = "accounts"
        let HTTPMethod = "GET"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            var accounts: JSON?
            let error = self.responseJson["errors"].int
            if self.success! {
                accounts = self.responseJson["accounts"]
            }
            completionHandler(success: requestSuccessfull, accounts: accounts!, error: error)
        })
    }
    
    func getAccount(requestBody: [String : String], completionHandler: (success: Bool, userAccount: JSON, error: Int?) -> Void) {
        let link = "account/\(requestBody["id"]!)"
        let HTTPMethod = "GET"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            var account: JSON?
            let error = self.responseJson["errors"].int
            if self.success! {
                account = self.responseJson["account"]
            }
            completionHandler(success: requestSuccessfull, userAccount: account!, error: error)
        })
    }
    
    func getFriendsForUser(requestBody: [String : String], completionHandler: (success: Bool, friends: JSON, error: Int?) -> Void) {
        let link = "friends/\(requestBody["id"]!)"
        let HTTPMethod = "GET"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            var friends: JSON?
            let error = self.responseJson["errors"].int
            if self.success! {
                friends = self.responseJson["friends"]
            }
            completionHandler(success: requestSuccessfull, friends: friends!, error: error)
        })
    }

    func deleteAccount(requestBody: [String: String], completionHandler:(success: Bool, accountDeleted: Bool, responseBody: JSON, error: Int?) -> Void) {
        let link = "account/\(requestBody["account_id"]!)uiop[===890-===-=0890-=98"
        let HTTPMethod = "DELETE"
       
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            var deleted: Bool? = nil
            let error = self.responseJson["errors"].int
            if self.success! {
                deleted = self.responseJson["deleted"].bool!
            }
            completionHandler(success: requestSuccessfull, accountDeleted: deleted!, responseBody: self.responseJson, error: error)
        })
    }

    func sendFriendRequest(requestBody: [String : String], completionHandler:(succes: Bool, sentRequest: Bool, userAccount: JSON!, responseBody: JSON, error: Int?) -> Void) {
        let link = "account/\(requestBody["account_id"]!)/requests/\(requestBody["target_account_id"]!)"
        let HTTPMethod = "PUT"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            var sentRequest: Bool? = nil
            var userAccount: JSON!
            let error = self.responseJson["error"].int
            if self.success! {
                sentRequest = self.responseJson["request_sent"].bool!
                userAccount = self.responseJson["account"]
            }
            completionHandler(succes: requestSuccessfull, sentRequest: sentRequest!, userAccount: userAccount, responseBody: self.responseJson, error: error)
        })
    }

    func confirmFriendRequest(requestBody: [String : String], completionHandler:(success: Bool, friendRequestConfirmed: Bool, userAccount: JSON!, responseBody: JSON, error: Int?) -> Void) {
        print("ApiRequest confirmFriendRequest")
        let link = "account/\(requestBody["account_id"]!)/confirms/\(requestBody["target_account_id"]!)"
        let HTTPMethod = "PUT"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            var confirmed: Bool? = nil
            var account: JSON!
            let error = self.responseJson["errors"].int
            if self.success! {
                confirmed = self.responseJson["request_confirmed"].bool
                account = self.responseJson["account"]
            }
            completionHandler(success: requestSuccessfull, friendRequestConfirmed: confirmed!, userAccount: account, responseBody: self.responseJson, error: error)
        })
    }
    
    func updateStatus(requestBody: [String : String], completionHandler:(success: Bool, responseBody: JSON, error: Int?) -> Void) {
        let link = "user/\(requestBody["status"]!)"
        let HTTPMethod = "PUT"
                
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            let error = self.responseJson["errors"].int
            completionHandler(success: requestSuccessfull, responseBody: self.responseJson, error: error)
        })
    }

    func deleteFriend(requestBody: [String : String], completionHandler:(success: Bool, friendDeleted: Bool?, userAccounts: JSON, responsBody: JSON, error: Int?) -> Void){
        let link = "friend/\(requestBody["buddy_id"]!)"
        let HTTPMethod = "DELETE"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, requestBody: requestBody, completion: {(requestSuccessfull) in
            var deleted: Bool? = nil
            let error = self.responseJson["error"].int
            var userAccounts: JSON!
            if self.success! {
                deleted = self.responseJson["buddyDeleted"].bool
                userAccounts = self.responseJson["user_accounts"]
            }
            completionHandler(success: requestSuccessfull, friendDeleted: deleted, userAccounts: userAccounts, responsBody: self.responseJson, error: error)
        })
    }

    func searchFriends(completionHandler:(success: Bool, searchFriends: JSON, error: Int?) -> Void) {
        let link = "search/friends"
        let HTTPMethod = "GET"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            let error = self.responseJson["error"].int
            completionHandler(success: requestSuccessfull, searchFriends: self.responseJson["friends"], error: error)
        })
    }

    func poke(requestBody: [String : String], completionHandler:(success: Bool, poked: Bool?, responseBody: JSON?, error: Int?) -> Void) {
        let link = "account/\(requestBody["id"]!)/pokes/\(requestBody["buddy_id"]!)"
        let HTTPMethod = "PUT"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            var poked: Bool? = nil
            let error = self.responseJson["errors"].int
            if self.success! {
                poked = self.responseJson["userPoked"].bool
            }
            completionHandler(success: requestSuccessfull, poked: poked, responseBody: self.responseJson, error: error)
        })
    }
    
    func dismissPoke(requestBody: [String : String], completionHandler:(success: Bool, pokeDissmised: Bool?, responseBody: JSON, error: Int?) -> Void) {
        let link = "account/\(requestBody["id"]!)/dissmised/\(requestBody["buddy_id"]!)"
        let HTTPMethod = "PUT"
        
        super.sendRequest(link, HTTPMethod: HTTPMethod, completion: {(requestSuccessfull) in
            var dismissed: Bool? = nil
            let error = self.responseJson["errors"].int
            if self.success! {
                dismissed = self.responseJson["poke_dissmissed"].bool
            }
            completionHandler(success: requestSuccessfull, pokeDissmised: dismissed, responseBody: self.responseJson, error: error)
        })
    }
}






