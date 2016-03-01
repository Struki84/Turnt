//
//  SearchViewController.swift
//  FlowTest
//
//  Created by Šimun on 09.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit
import SwiftyJSON

class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, SearchFriendsCellViewDelegate {

    @IBOutlet weak var searchTableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var doneButton: UIButton!
    
    var searchActive : Bool = false
    var accountId: NSNumber!
    var filtered:[JSON] = []
    var friends: [JSON] = []
    
    let apiRequest: ApiRequest! = ApiRequest()
    
    @IBAction func searchDone() {
        self.dismissViewControllerAnimated(true, completion: {})
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        searchBar.setImage(UIImage(named: "Loupe"), forSearchBarIcon: UISearchBarIcon.Search, state: UIControlState.Normal)
        searchBar.showsCancelButton = true
        var cancelButton: UIButton
        for subView in searchBar.subviews[0].subviews {
            if subView.isKindOfClass(NSClassFromString("UINavigationButton")!) {
                cancelButton = subView as! UIButton
                cancelButton.setTitle("Cancel".localized, forState: UIControlState.Normal)
            }
        }
        
        searchTableView.dataSource = self
        searchTableView.delegate = self
        searchTableView.separatorColor = UIColor.TurntLightGray();
        
        doneButton.setTitle("DONE".localized, forState: UIControlState.Normal)
        doneButton.frame.size.width = UIScreen.mainScreen().bounds.size.width
        
        apiRequest.searchFriends { (success, searchFriends, error) -> Void in
            if success {
                self.friends = searchFriends.arrayValue
                
                let alreadyAddedFriends = (Account.get(self.accountId)?.friends)!
                let friendsIds : NSMutableArray = []
                for friend in alreadyAddedFriends {
                    friendsIds.addObject(friend.valueForKey("friend_account_id")!.integerValue)
                }
                
                var filteredFriends : [JSON] = []
                for user in (self.friends) {
                    if (!friendsIds.containsObject(user["id"].int!)) {
                        filteredFriends.append(user)
                    }
                }
                self.friends = filteredFriends
                self.searchTableView.reloadData()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: - Search Bar Delegates
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        searchActive = true;
    }
    
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchActive = false;
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        
        filtered = friends.filter({ (friend) -> Bool in
            let tmp: NSString = friend["username"].stringValue
            let range = tmp.rangeOfString(searchText, options: NSStringCompareOptions.CaseInsensitiveSearch)
            return range.location != NSNotFound
        })
        if(filtered.count == 0){
            searchActive = false;
        } else {
            searchActive = true;
        }
        searchTableView.reloadData()
    }
    
    //MARK: - Table View Delegates
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 64
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(searchActive) {
            return filtered.count
        }
        return friends.count;
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = searchTableView.dequeueReusableCellWithIdentifier("SearchCell") as! SearchFriendsCellView
        cell.delegate = self
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        
        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsetsZero
        cell.layoutMargins = UIEdgeInsetsZero
        
        //TODO: add logic
        cell.connectionStatusImageView.image = UIImage(named: "GRAY-DOT");
        cell.connectionStatusLabel.text = "Offline"
        
        var friendsList: [JSON] = []

        if searchActive {
            let filterResultUsername : String = filtered[indexPath.row]["username"].stringValue
            cell.addFriendButton.tag = indexPath.row
            cell.friendUsername.text = "\(filterResultUsername)"
            friendsList = filtered
        } else {
            let username: String = self.friends[indexPath.row]["username"].stringValue
            cell.addFriendButton.tag = indexPath.row
            cell.friendUsername.text = "\(username)"
            friendsList = friends
        }
        
        //TODO: not sure if boolValue == true is correct statement
        if (friendsList[indexPath.row]["online"].boolValue == true) {
            cell.connectionStatusLabel.text = "Online".localized
            cell.connectionStatusImageView.image = UIImage(named: "GREEN-DOT")
        } else {
            cell.connectionStatusLabel.text = "Offline".localized
            cell.connectionStatusImageView.image = UIImage(named: "GRAY-DOT")
        }
        
        if (friendsList[indexPath.row]["image"].rawString()!.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 2000) {
            if let image: String = friendsList[indexPath.row]["image"].string {
                let imgData: NSData = NSData(base64EncodedString: image, options:NSDataBase64DecodingOptions(rawValue: 0))!
                cell.profileImage = UIImage(data: imgData)
            }
        } else {
            cell.profileImage = UIImage(named: "profile_placeholder")
        }
        
        return cell;
    }
   
    func appendFriend(sender: AnyObject) {
        let button = sender as! UIButton
        let account = Account.get(accountId)
        var friendId = 0
        if searchActive {
            friendId = self.filtered[sender.tag!]["id"].intValue
        } else {
            friendId = self.friends[sender.tag!]["id"].intValue
        }
        let requestBody: [String: String] = [
            "account_id" : "\(account!.id)",
            "target_account_id" : "\(friendId)"
        ]
        
        doneButton.enabled = false
        apiRequest.sendFriendRequest(requestBody, completionHandler: { (success, sentRequest, userAccount, responseBody, error) -> Void in
            if success {
                if sentRequest {
                    self.apiRequest.getFriendsForUser(["id": "\(userAccount["id"])"], completionHandler: { (success, friends, error) -> Void in
                        if (success) {
                            let accountToUpdate: Account = Account.get(userAccount["id"].int!)!
                            accountToUpdate.friends = []
                            for i in 0..<friends.count {
                                Friend.create(friends[i], forAccount: accountToUpdate).save()
                            }
                            accountToUpdate.save()
                            self.doneButton.enabled = true
                        } else {
                            print("error while updating user friends: \(error)")
                        }
                    })
                }
            }
        })
        
        if searchActive {
            friends.removeAtIndex(friends.indexOf(filtered[button.tag])!)
            filtered.removeAtIndex(button.tag)
        } else {
            friends.removeAtIndex(button.tag)
        }
        
        searchTableView.reloadData()
    }
}