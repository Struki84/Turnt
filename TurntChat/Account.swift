//
//  Account.swift
//  TurntChat
//
//  Created by Šimun on 19.07.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import SwiftyJSON

class Account: NSManagedObject {
    
    @NSManaged var active: NSNumber
    @NSManaged var activeated_on: Date
    @NSManaged var deactivated_on: Date
    @NSManaged var defaultAccount: NSNumber
    @NSManaged var id: NSNumber
    @NSManaged var password: String
    @NSManaged var image: Data
    @NSManaged var username: String
    @NSManaged var friends: NSSet
    @NSManaged var visible: NSNumber
    @NSManaged var user_id: NSNumber
    
    static let entityName: String = "Account"
    static let context = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
    static let apiRequest = ApiRequest()
    
    var profileImage: UIImage? {
        get {
            var image: UIImage? = UIImage(named: "AddPhoto")
            if self.image.count > 0 {
                image = UIImage(data: self.image)
            }
            return image
        }
        
        set(uploadedImage) {
            self.image = UIImagePNGRepresentation(uploadedImage!)!
        }
    }
    
    //MARK: Static functions
    
    //Create record in context and return new entity
    class func create(_ username: String, image: Data?) -> Account {
        let newAccount = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context!) as! Account
        newAccount.username = username
        if let img = image {
            newAccount.image = img
        }
        return newAccount
    }
    
    //Create record in remote db and sync redcords with local db
    class func create(_ accountData: JSON, completed: (_ error: String?) -> Void)  {
        let newAccount = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context!) as! Account
        newAccount.id = accountData["id"].intValue
        newAccount.username = accountData["username"].stringValue
        newAccount.visible = accountData["visible"].boolValue
        newAccount.active = accountData["active"].boolValue
        newAccount.user_id = accountData["user_id"].intValue
        newAccount.save()
    }
    
    //Get record by id
    class func get(_ id: NSNumber) -> Account? {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let predicate = NSPredicate(format: "id == %@", id)
        var accounts: [Account] = []
        
        fetchRequest.predicate = predicate
        if let fetchResults = (try? context!.fetch(fetchRequest)) as? [Account] {
            accounts = fetchResults
        }
        
        if accounts.count > 0 {
            return accounts[0]
        }
        else {
            return nil
        }
    }
    
    //Get all records
    class func all() -> [Account] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let sortDescriptor = NSSortDescriptor(key: "id", ascending: true)
        var accounts: [Account] = []
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let fetchResults = (try? context!.fetch(fetchRequest)) as? [Account] {
            accounts = fetchResults
        }
        
        return accounts
    }
    
    //Find record by username
    class func findByUsername(_ username: String) -> Account? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let predicate = NSPredicate(format: "username == %@", username)
        var accounts: [Account] = []
        
        fetchRequest.predicate = predicate
        if let fetchResults = (try? context!.fetch(fetchRequest)) as? [Account] {
            accounts = fetchResults
        }
        
        if accounts.count > 0 {
            return accounts[0]
        }
        else {
            return nil
        }
    }
    
    //Delete all records
    class func deleteAll() {
        var accounts = all()
        for account in accounts {
            context!.delete(account as NSManagedObject)
        }
        accounts.removeAll(keepingCapacity: false)
        do {
            try context!.save()
        } catch _ {
        }
    }
    
    //Get last inserted id
    class func lastInsertedId() -> NSNumber {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let sortDescriptor = NSSortDescriptor(key: "id", ascending: false)
        var accounts: [Account] = []
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let fetchResults = (try? context!.fetch(fetchRequest)) as? [Account] {
            accounts = fetchResults
        }
        
        return accounts[0].id
    }
    
    class func syncFriendsForAccount(_ userAccount: JSON) {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Account.entityName)
        let predicate = NSPredicate(format: "id == \(userAccount["id"])")
        fetchRequest.predicate = predicate
        
        if let fetchResults = (try? context!.fetch(fetchRequest)) as? [Account] {
            let oldAccount = fetchResults[0]
            oldAccount.friends = []
            for (_, friend): (String, JSON) in userAccount["friends"] {
                Friend.create(friend, forAccount: oldAccount).save()
            }
        }
    }
    
    class func syncRecords(_ userAccounts: JSON) {
        Account.deleteAll()
        
//        print("sync records user Accounts: \(userAccounts)")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        for (_, account): (String, JSON) in userAccounts {
            let newAccount: Account = Account.create(account["username"].stringValue, image: nil)
            newAccount.active = account["active"].boolValue
            newAccount.id = account["id"].intValue
            newAccount.user_id = account["user_id"].intValue
            newAccount.visible = account["visible"].boolValue
            newAccount.setDefault(true)
            newAccount.activeated_on = dateFormatter.date(from: account["activated_on"].stringValue)!
            
            if (account["image"].rawString()!.lengthOfBytes(using: String.Encoding.utf8) > 2000) {
//                newAccount.isImageAddedByUser = true
                if let image: String = account["image"].string {
                    let imgData: Data = Data(base64Encoded: image, options:NSData.Base64DecodingOptions(rawValue: 0))!
                    newAccount.image = imgData
                }
            } else {
                newAccount.image = Data.init()
            }
    
            newAccount.save()
            
            for (_, friend): (String, JSON) in account["friends"] {
                Friend.create(friend, forAccount: newAccount).save()
            }
        }
    }
    
    
    //MARK: Instance methods
    
    //Save Record
    func save(){
        let context = Account.context
        do {
            try context!.save()
        } catch let error as NSError {
            print(error)
        }
    }
    
    func remove() {
        let context = Account.context
        context!.delete(self)

        do {
            try context!.save()
        }
        catch let error as NSError {
            print(error)
        }
    }
    
    func getNotifications() -> Int {
        var count: Int = 0
        let friends = self.friends.allObjects
        for friend in friends as! [Friend] {
            if friend.poked_me as Bool {
                count += 1
            }
        }
        return count
    }
    
    func resetNotifications() {
        let friends = self.friends.allObjects
        for friend in friends as! [Friend] {
            friend.poked_me = false
        }
    }
    
    func isImageAddedByUser() -> Bool {
        if self.image.count > 0 {
            return true
        } else {
            return false
        }
    }
    
    func getImage() -> UIImage? {
        var image: UIImage? = UIImage(named: "AddPhoto")
        if self.image.count > 0 {
            image = UIImage(data: self.image)
        }
        if let _ = image {
            return image
        }
        else {
            return nil
        }
    }
    
    func getChatImage() -> UIImage? {
        var image: UIImage? = UIImage(named: "profile_placeholder")
        if self.image.count > 0 {
            image = UIImage(data: self.image)
        }
        if let _ = image {
            return image
        }
        else {
            return nil
        }
    }
    
//    func setProfileImage(image: UIImage) {
//        self.image = UIImagePNGRepresentation(image)!
//    }
    
    func setDefault(_ on: Bool) {
        let context = Account.context
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Account.entityName)
        let predicate = NSPredicate(format: "defaultAccount == 1")
        fetchRequest.predicate = predicate
        
        if on {
            if let fetchResults = (try? context!.fetch(fetchRequest)) as? [Account] {
                if fetchResults.count > 0 {
                    let oldDefaultAccount: Account = fetchResults[0]
                    oldDefaultAccount.defaultAccount = false
                    oldDefaultAccount.save()
                }
            }
        }
        
        self.defaultAccount = on as NSNumber
    }
}
