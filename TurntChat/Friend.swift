//
//  Friend.swift
//  TurntChat
//
//  Created by Šimun on 19.07.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import SwiftyJSON

class Friend: NSManagedObject {
    
    @NSManaged var account_id: NSNumber
    @NSManaged var confirmed: NSNumber
    @NSManaged var online: NSNumber
    @NSManaged var friend_account_id: NSNumber
    @NSManaged var id: NSNumber
    @NSManaged var poked_me: NSNumber
    @NSManaged var username: String
    @NSManaged var image: Data
    @NSManaged var account: Account
    
    static let entityName: String = "Friend"
    static let context = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
    
    //MARK: Static functions
    
    //Create record in context and return new entity
    class func create(_ withData: JSON, forAccount: Account) -> Friend {
        let newFriend = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context!) as! Friend
        newFriend.id = withData["id"].intValue
        newFriend.username = withData["username"].stringValue
        newFriend.account_id = forAccount.id
        newFriend.friend_account_id = withData["friend_account_id"].intValue as NSNumber
        newFriend.poked_me = withData["poked_me"].boolValue
        newFriend.confirmed = withData["confirmed"].boolValue
        newFriend.online = withData["online"].numberValue
        newFriend.account = forAccount
        
        if (withData["image"].rawString()!.lengthOfBytes(using: String.Encoding.utf8) > 2000) {
            if let image: String = withData["image"].string {
                let imgData: Data = Data(base64Encoded: image, options:NSData.Base64DecodingOptions(rawValue: 0))!
                newFriend.image = imgData
            }
        } else {
            newFriend.image = Data.init()
        }
        
        
        return newFriend
    }
    
    class func create(_ withData: [String: AnyObject], forAccount: Account) -> Friend {
        let newFriend = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context!) as! Friend
        newFriend.id = withData["id"] as! NSNumber
        newFriend.username = withData["username"] as! String
        newFriend.account_id = forAccount.id
        newFriend.friend_account_id = withData["friend_account_id"] as! NSNumber
        newFriend.poked_me = withData["poked_me"] as! NSNumber
        newFriend.confirmed = withData["confirmed"] as! NSNumber
        newFriend.online = withData["online"] as! NSNumber
        newFriend.account = forAccount as Account
        return newFriend
    }

    
    
    //Get record by id
    class func get(_ id: NSNumber) -> Friend? {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let predicate = NSPredicate(format: "id == %@", id)
        var accounts: [Friend] = []
        
        fetchRequest.predicate = predicate
        if let fetchResults = (try? context!.fetch(fetchRequest)) as? [Friend] {
            accounts = fetchResults
        }
        
        return accounts[0]
    }
    
    //Get all records
    
    class func all() -> [Friend] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let sortDescriptor = NSSortDescriptor(key: "id", ascending: true)
        var friends: [Friend] = []
        
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let fetchResults = (try? context!.fetch(fetchRequest)) as? [Friend] {
            friends = fetchResults
        }
        
        return friends
    }
    
    //Find record by username
    class func findByUsername(_ username: String) -> Friend? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let predicate = NSPredicate(format: "username == %@", username)
        var friends: [Friend] = []
        
        fetchRequest.predicate = predicate
        if let fetchResults = (try? context!.fetch(fetchRequest)) as? [Friend] {
            friends = fetchResults
        }
        
        if friends.count > 0 {
            return friends[0]
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
    
    
    //MARK: Instance methods
    
    //Save Record
    func save(){
        let context = Friend.context
        do {
            try context!.save()
        } catch let error as NSError {
            print(error)
        }
    }
    
    func remove() {
        let context = Friend.context
        context!.delete(self)
        do {
            try context!.save()
        } catch let error as NSError {
            print(error)
        }
    }
    
    func getImage() -> UIImage {
        
//        print("image lenght: \(self.image.length)")
        var image: UIImage = UIImage(named: "profile_placeholder")!
        if self.image.count > 0 {
            image = UIImage(data: self.image)!
        }
        return image
    }
    
    func setProfileImage(_ image: UIImage) {
        self.image = UIImagePNGRepresentation(image)!
    }
    
}
