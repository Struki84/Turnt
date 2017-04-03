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
        self.dismiss(animated: true, completion: {})
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        searchBar.setImage(UIImage(named: "Loupe"), for: UISearchBarIcon.search, state: UIControlState())
        searchBar.showsCancelButton = true
        var cancelButton: UIButton
        for subView in searchBar.subviews[0].subviews {
            if subView.isKind(of: NSClassFromString("UINavigationButton")!) {
                cancelButton = subView as! UIButton
                cancelButton.setTitle("Cancel".localized, for: UIControlState())
            }
        }
        
        searchTableView.dataSource = self
        searchTableView.delegate = self
        searchTableView.separatorColor = UIColor.TurntLightGray();
        
        doneButton.setTitle("DONE".localized, for: UIControlState())
        doneButton.frame.size.width = UIScreen.main.bounds.size.width
        
        apiRequest.searchFriends { (success, searchFriends, error) -> Void in
            if success {
                self.friends = searchFriends.arrayValue
                
                let alreadyAddedFriends = (Account.get(self.accountId)?.friends)!
                let friendsIds : NSMutableArray = []
                for friend in alreadyAddedFriends {
                    friendsIds.add(friend.value(forKey: "friend_account_id")!.intValue)
                }
                
                var filteredFriends : [JSON] = []
                for user in (self.friends) {
                    if (!friendsIds.contains(user["id"].int!)) {
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
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchActive = true;
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchActive = false;
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filtered = friends.filter({ (friend) -> Bool in
            let tmp: NSString = friend["username"].stringValue
            let range = tmp.range(of: searchText, options: NSString.CompareOptions.caseInsensitive)
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
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(searchActive) {
            return filtered.count
        }
        return friends.count;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = searchTableView.dequeueReusableCell(withIdentifier: "SearchCell") as! SearchFriendsCellView
        cell.delegate = self
        cell.selectionStyle = UITableViewCellSelectionStyle.none
        
        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsets.zero
        cell.layoutMargins = UIEdgeInsets.zero
        
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
        
        if (friendsList[indexPath.row]["image"].rawString()!.lengthOfBytes(using: String.Encoding.utf8) > 2000) {
            if let image: String = friendsList[indexPath.row]["image"].string {
                let imgData: Data = Data(base64Encoded: image, options:NSData.Base64DecodingOptions(rawValue: 0))!
                cell.profileImage = UIImage(data: imgData)
            }
        } else {
            cell.profileImage = UIImage(named: "profile_placeholder")
        }
        
        return cell;
    }
   
    func appendFriend(_ sender: AnyObject) {
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
        
        doneButton.isEnabled = false
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
                            self.doneButton.isEnabled = true
                        } else {
                            print("error while updating user friends: \(error)")
                        }
                    })
                }
            }
        })
        
        if searchActive {
            friends.remove(at: friends.index(of: filtered[button.tag])!)
            filtered.remove(at: button.tag)
        } else {
            friends.remove(at: button.tag)
        }
        
        searchTableView.reloadData()
    }
}
