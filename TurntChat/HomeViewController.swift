//
//  HomeViewController.swift
//  FlowTest
//
//  Created by Šimun on 09.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, AddNewAccountDelegate, PurchaseAccountViewDelegate, FriendTableViewCellDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate {

   
    @IBOutlet weak var friendsTableView: UITableView!
    @IBOutlet weak var accountScrollView: UIScrollView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    var infoView: InfoView!
    var notificationView: UITextView!
    let msgHeight: CGFloat = 35.0;
    
    let apiRequest: ApiRequest! = ApiRequest()
    let imagePicker: UIImagePickerController = UIImagePickerController()
    
    var refreshControl = UIRefreshControl()
    var accounts: [Account]?
    var currentAccountPage: Int = 0
    var currentAccountId: Int? = 0
    var firstTimeAfterLogin: Bool = true
    
    //MRAK: - Lifecycle
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MRAK: - View Lifecycle
    override func viewDidAppear(animated: Bool) {
//        friendsTableView.reloadData()
        self.reloadFriendsTable()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addInfoView()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "requestTimeout", name: RequestNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "displayNotification:", name: "pushNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "becameActive", name: "appIsActive", object: nil)
        
        friendsTableView.delegate = self
        friendsTableView.dataSource = self
        friendsTableView.separatorColor = UIColor.TurntLightGray()
        
        let image = UIImage(named: "LOGO3")
        let imageView = UIImageView(image: image)
        self.navigationItem.titleView = imageView
        
        //TODO might be as UINavigationBar extension
        let navigationBar = self.navigationController?.navigationBar
        navigationBar?.setBackgroundImage(UIImage(), forBarPosition: UIBarPosition.Any, barMetrics: UIBarMetrics.Default)
        navigationBar?.shadowImage = UIImage()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.Plain, target: nil, action: nil)
        
        accountScrollView.backgroundColor = UIColor.TurntPink()
        
        // set up the refresh control
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.friendsTableView.addSubview(refreshControl)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
       
        self.accounts = Account.all()
        
        if(firstTimeAfterLogin) {
            var numAco = 0
            for aco in self.accounts! {
                numAco += 1
                if (aco == Account.findByUsername(NSUserDefaults.standardUserDefaults().valueForKey("loginAs")! as! String)) {
                    self.currentAccountPage = numAco - 1
                    currentAccountId = aco.id as Int?
                }
            }
        }
        
        if currentAccountPage >= self.accounts!.count {
           currentAccountPage = self.accounts!.count - 1
        }

        self.currentAccountId = self.accounts![self.currentAccountPage].id as Int?
        var accountScrollViewWidthModifier: CGFloat = CGFloat(self.accounts!.count)
        var numberOffAccountViews: Int = self.accounts!.count

        if self.accounts!.count < ConfigManager.sharedInstance.maxAllowedAccounts! {
            accountScrollViewWidthModifier = accountScrollViewWidthModifier + 1
            numberOffAccountViews = numberOffAccountViews + 1
        }

        let accountScrollViewWidth: CGFloat = self.view.frame.size.width * accountScrollViewWidthModifier
        self.accountScrollView.contentSize = CGSizeMake(accountScrollViewWidth, self.accountScrollView.frame.size.height)
        self.accountScrollView.delegate = self
        
        for subview in self.accountScrollView.subviews{
            subview.removeFromSuperview()
        }
        
        for var i = 0; i < numberOffAccountViews; i++ {
            self.createAccountView(i)
        }
        
        let viewStartingPoint = CGPointMake(CGFloat(currentAccountPage) * self.view.frame.size.width, 0)
        self.accountScrollView.setContentOffset(viewStartingPoint, animated: true)

        self.reloadFriendsTable()
    }
    
    //MARK: - Layout
    func addInfoView() {
        let infoViewX: CGFloat = (self.view.frame.size.width - 320)/2
        let calculatedTableViewHeight: CGFloat = self.view.frame.height - self.accountScrollView.frame.size.height - 66
        let infoViewY: CGFloat = (calculatedTableViewHeight-150)/2
        infoView = InfoView.init(frame: CGRectMake(infoViewX, infoViewY, 320, 150))
        self.friendsTableView.addSubview(infoView)
    }
    
    func createAccountView(atIndex: Int) {
        let xOffset: CGFloat = self.view.frame.size.width * CGFloat(atIndex)
        let accountViewFrame: CGRect = CGRect(
            x: xOffset,
            y: 0,
            width: self.view.frame.size.width,
            height: accountScrollView.frame.size.height
        )
        
        if atIndex < self.accounts!.count {
            let account: Account = accounts![atIndex]
            let accountNotifications = account.getNotifications()
            let accountView: AccountView = AccountView(frame: accountViewFrame)
            
            accountView.tag = atIndex
            accountView.titleLabel.text = "\(account.username)"
            accountView.accountImage.image = account.getImage()!
            if accountNotifications > 0 {
                accountView.notificationLabel.text = "\(accountNotifications)"
                accountView.notificationLabel.hidden = false
            }
            
            let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:Selector("imageTapped:"))
            accountView.accountImage.userInteractionEnabled = !account.isImageAddedByUser()
            accountView.accountImage.addGestureRecognizer(tapGestureRecognizer)
            
            accountScrollView.addSubview(accountView)
        }
        else {
            if ConfigManager.sharedInstance.paidApp! {
                
                let addAccountView: AddNewAccountView = AddNewAccountView(frame: accountViewFrame)
                addAccountView.delegate = self
                accountScrollView.addSubview(addAccountView)
            }
            else {
                let purchaseAccountView: PurchaseAccountView = PurchaseAccountView(frame: accountViewFrame)
                purchaseAccountView.delegate = self
                accountScrollView.addSubview(purchaseAccountView)
            }
        }
    }
    
    // MARK: - User Interaction
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "goToChat" {
//            print("goToChat segue performing")
            let cell: UITableViewCell = sender as! UITableViewCell
            let ChatController = segue.destinationViewController as! ChatViewController
            ChatController.friendId = accounts![currentAccountPage].friends.allObjects[cell.tag].id as Int?
            ChatController.accountId = currentAccountId
            
//            let account: Account = accounts![currentAccountPage]
//            account.resetNotifications()
        }
        else if segue.identifier == "goToSettings" {
//            print("Page \(self.currentAccountPage), id : \(accounts![currentAccountPage].id)")
            let SettingsController = segue.destinationViewController as! SettingsViewController
            SettingsController.accountId = accounts![currentAccountPage].id as NSNumber
        }
        else if segue.identifier == "goToSearch" {
//            print("goToSearch segue performing")
            let SearchController = segue.destinationViewController as! SearchViewController
            SearchController.accountId = accounts![currentAccountPage].id as NSNumber
        }
    }
    
    func refresh(sender: AnyObject) {
        self.apiRequest.getFriendsForUser(["id": "\(self.accounts![self.currentAccountPage].id)"], completionHandler: { (success, friends, error) -> Void in
            if (success) {
                let accountToUpdate: Account = Account.get(self.accounts![self.currentAccountPage].id)!
                accountToUpdate.friends = []
                for i in 0..<friends.count {
//                    print("friend \(i): \(friends[i])")
                    Friend.create(friends[i], forAccount: accountToUpdate).save()
                }
                accountToUpdate.save()
                self.refreshControl.endRefreshing()
//                self.friendsTableView.reloadData()
                self.reloadFriendsTable()
            } else {
                print("error while refreshing: \(error)")
            }
        })
    }
    
    func addNewAccount(parentView: AddNewAccountView, inputUsername: String) -> Bool {
        apiRequest.createAccount(["username" : inputUsername], completionHandler: { (success, accountCreated, userAccounts, responseBody, error) -> Void in
            if success {
                print("Account Created")
                Account.create(responseBody["account"], completed: {_ in })
                self.accounts = Account.all()
                UIView.animateWithDuration(0.4, animations: { () -> Void in
                    if self.accounts!.count == ConfigManager.sharedInstance.maxAllowedAccounts! - 1 {
                        parentView.removeFromSuperview()
                    }
                    else {
                        self.accountScrollView.contentSize = CGSize(width: self.accountScrollView.contentSize.width + self.view.frame.width, height:self.accountScrollView.frame.size.height)
                        parentView.frame.origin.x += self.view.frame.width
                    }
                    }, completion: { (completed) -> Void in
                        self.navigationItem.rightBarButtonItem?.enabled = true
                        self.navigationItem.leftBarButtonItem?.enabled = true
                        self.viewWillAppear(true)
                        self.accounts = Account.all()
                        self.createAccountView(self.accounts!.count - 1)
                        let viewStartingPoint = CGPointMake(CGFloat(self.accounts!.count - 1) * self.view.frame.size.width, 0)
                        self.accountScrollView.setContentOffset(viewStartingPoint, animated: true)
//                        self.friendsTableView.reloadData()
                        self.reloadFriendsTable()
                })
            }
        })
        return true
    }
    
    //TODO: debug this method
    func approveFriend(button: UIButton) {
        print("homeVC approveFriend button pressed")
        
        let approvedFriend: Friend = accounts![currentAccountPage].friends.allObjects[button.tag] as! Friend
        let requestBody: [String: String] = [
            "target_account_id": "\(approvedFriend.id)",
            "account_id": "\(currentAccountId!)"
        ]
        button.enabled = false
        apiRequest.confirmFriendRequest(requestBody) { (success, friendRequestConfirmed, userAccount, responseBody, error) -> Void in
            if success {
                if friendRequestConfirmed {
                    approvedFriend.confirmed = true
                    approvedFriend.poked_me = false
                    approvedFriend.save()
                    self.reloadFriendsTable()
//                    self.friendsTableView.reloadData()
                }
            }
        }
    }
    
    func imageTapped(img: AnyObject) {
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.sourceType = UIImagePickerControllerSourceType.SavedPhotosAlbum
        imagePicker.navigationBar.barTintColor = UIColor.TurntPink()
        imagePicker.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.whiteColor()]
        imagePicker.navigationBar.tintColor = UIColor.whiteColor()
        imagePicker.navigationBar.barStyle = .Black
        imagePicker.navigationBar.translucent = false
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.SavedPhotosAlbum){
            self.presentViewController(imagePicker, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : AnyObject]!) {
        self.dismissViewControllerAnimated(true, completion: { () -> Void in
            
            self.accounts![self.currentAccountPage].image = UIImageJPEGRepresentation(image, 0.5)!
            self.accounts![self.currentAccountPage].save()
            
            self.createAccountView(self.currentAccountPage)
            
            let accountToUpdate = self.accounts![self.currentAccountPage]
            
            let requestBody: [String:String] = [
                "account_id": "\(accountToUpdate.id)",
                "username"  : "\(accountToUpdate.username)",
                "active"    : "\(accountToUpdate.active)",
                "visible"   : "\(accountToUpdate.visible)",
                "image"     : accountToUpdate.image.base64EncodedStringWithOptions([]),
            ]
            
            //TODO: Handle errors
            self.apiRequest.updateAccount(requestBody) { (success, accountUpdated, userAccounts, responseBody, error) -> Void in
                print("IMAGE PICKED UPDATE ACCOUNT >>>  success: \(success), accountUpdated: \(accountUpdated), userAccounts: \(userAccounts), responseBody: \(responseBody)  ")
                if success {
                    if let updated = accountUpdated {
                        if updated {
                            print("after image upload userAccount: \(userAccounts)")
                            Account.syncRecords(userAccounts)
                        }
                    }
                }
            }
        })
    }
    
    //MARK: - Observer Actions
    func requestTimeout() {
        showAlert(ConfigManager.sharedInstance.alertMsg!["server_response_500"])
    }
    
    func becameActive() {
        reloadFriendsTable()
    }
    
    func displayNotification(n: NSNotification) {
        reloadFriendsTable()
        let nData = n.userInfo!["aps"] as! NSDictionary
        let alert = nData.valueForKey("alert")
        if (alert != nil) {
            displayNotificationWithText(alert as! String)
        }
    }
    
    //MARK: - Table View Delegate methods
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 64
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var friendsCount: Int = 0
        if currentAccountPage < self.accounts!.count {
            if let account = accounts?[currentAccountPage] {
                friendsCount = account.friends.count
            }
        }
        
        if (friendsCount > 0) {
            infoView.hidden = true
        } else {
            infoView.hidden = false
        }
        
        return friendsCount
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        let row = indexPath.row
        let cell = friendsTableView.dequeueReusableCellWithIdentifier("FriendCell", forIndexPath: indexPath) as! FriendTableViewCell
        let friends = accounts![currentAccountPage].friends.allObjects
        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsetsZero
        cell.layoutMargins = UIEdgeInsetsZero
        cell.tag = row
        cell.delegate = self
        if friends.count != 0 {
            
            let friend = friends[row] as! Friend

            cell.friendProfileImageView.image = friend.getImage()
            cell.friendUsername.text = "\(friend.username)"
            cell.approveFriendButton.tag = row
            
            if friend.confirmed as Bool != true {
                cell.connectionStatusLabel.text = "Pending approval..."
                if (friend.poked_me as Bool == true) {
                    cell.approveFriendButton.setBackgroundImage(UIImage(named: "PLUS"), forState: UIControlState.Normal)
                    cell.approveFriendButton.hidden = false
                    cell.approveFriendButton.enabled = true
                }
                else {
                    cell.approveFriendButton.hidden = true
                }
            }
            else {
                cell.approveFriendButton.hidden = false
                cell.approveFriendButton.enabled = true
                if (friend.poked_me as Bool) {
                    cell.approveFriendButton.setBackgroundImage(UIImage(named: "NOTIFICATION1"), forState: UIControlState.Normal)
                } else {
                    cell.approveFriendButton.setBackgroundImage(UIImage(named: "NOTIFICATION2"), forState: UIControlState.Normal)
                }

                if friend.online as Bool {
                    cell.connectionStatusLabel.text = "Online".localized
                    cell.connectionStatusImageView.image = UIImage(named: "GREEN-DOT")
                } else {
                    cell.connectionStatusLabel.text = "Offline".localized
                    cell.connectionStatusImageView.image = UIImage(named: "GRAY-DOT")
                }
            }
        }
        else {
            cell.friendUsername.text = "fail"
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell = friendsTableView.dequeueReusableCellWithIdentifier("FriendCell", forIndexPath: indexPath) as! FriendTableViewCell
        cell.tag = indexPath.row
        
        let friends = accounts![currentAccountPage].friends.allObjects
        let friend = friends[indexPath.row] as! Friend
        if (friend.confirmed == 1) {
            performSegueWithIdentifier("goToChat", sender: cell)
        }
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .Normal, title: "Delete") { (rowAction:UITableViewRowAction, indexPath:NSIndexPath) -> Void in
            let friend: Friend = self.accounts![self.currentAccountPage].friends.allObjects[indexPath.row] as! Friend
                let requestBody: [String: String] = [
                    "account_id" : "\(self.currentAccountId!)",
                    "buddy_id" : "\(friend.id)"]
                friend.remove()
                self.apiRequest.deleteFriend(requestBody, completionHandler: { (success, friendDeleted, userAccounts, responsBody, error) -> Void in
                    print("deleteFriend userAccounts: \(userAccounts)")
                    print("deleteFriend responsBody: \(responsBody)")
                    if success {
                        if let deleted = friendDeleted {
                            if deleted {
                                Account.syncRecords(userAccounts)
                                self.accounts = Account.all()
//                                self.friendsTableView.reloadData()
                                self.reloadFriendsTable()
                            }
                        }
                    }
                })
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
        }
        deleteAction.backgroundColor = UIColor.TurntPink()
        return [deleteAction]
    }
    
    //MARK: - Scroll View Delegate methods
    func scrollViewDidScroll(scrollView: UIScrollView) {

        if(firstTimeAfterLogin) {
            self.firstTimeAfterLogin = false
        } else {
            if scrollView == accountScrollView {
                let width = scrollView.frame.size.width;
                let page = Int((scrollView.contentOffset.x + (0.5 * width)) / width);
                if (self.currentAccountPage != page) {
                    self.currentAccountPage = page
                    self.navigationItem.rightBarButtonItem?.enabled = true
                    self.navigationItem.leftBarButtonItem?.enabled = true

                    if page < self.accounts!.count {
                        currentAccountId = accounts![page].id as Int?
                    }
                    else {
                        self.navigationItem.rightBarButtonItem?.enabled = false
                        self.navigationItem.leftBarButtonItem?.enabled = false
                    }
//                    friendsTableView.reloadData()
                    self.reloadFriendsTable()
                }
            }
        }
    }
    
    //MARK: - Helpers
    func showIAPPurchase(parentView: PurchaseAccountView) {
        let alertController = UIAlertController(
            title: "Purchase more accounts!",
            message: "In App Purchase is not enabled at the moment, It will be available in the next beta realese",
            preferredStyle: UIAlertControllerStyle.Alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default,handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func showAlert(content: String?){
        let alertController = UIAlertController(
            title: "Ooops! There was a problem!",
            message: content,
            preferredStyle: UIAlertControllerStyle.Alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default,handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }

    func reloadFriendsTable(){
        print(" ")
        print("homeVC reloadFriendsTable")
        
        apiRequest.getAccounts { (success, accounts, error) -> Void in
            if success {
                Account.syncRecords(accounts)
                self.accounts = Account.all()
                for user in self.accounts! {
                    print("   \(user.username)'s chat list (\(user.friends.count)): ")
                    for friend in user.friends {
                        print("     -- \(friend.username)")
                    }
                }
                self.createAccountView(self.currentAccountPage)
                self.friendsTableView.reloadData()
            }
        }
    }
    
    //MARK: - Display notification
    func displayNotificationWithText(text: String) {
//        if (!self.view.subviews.contains(self.notificationView)) {
            self.notificationView = UITextView.init(frame: CGRectMake(0, -msgHeight, self.view.frame.size.width, msgHeight))
            self.notificationView.text = text
            self.notificationView.userInteractionEnabled = false
            self.notificationView.textAlignment = .Center
            self.notificationView.font = UIFont.systemFontOfSize(15)
            self.notificationView.opaque = true
            self.notificationView.textColor = UIColor.TurntPink()
            self.notificationView.backgroundColor = UIColor(white: 1, alpha: 0.7)
            let tap = UITapGestureRecognizer.init(target: self, action:"hideNotification:")
            tap.delegate = self
            self.notificationView.addGestureRecognizer(tap)
            self.view.addSubview(notificationView)
            UIView.animateWithDuration(0.7, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.7, options: [], animations: {
                self.notificationView.frame.origin.y += self.msgHeight
                }, completion: nil)
            let dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC)))
            dispatch_after(dispatchTime, dispatch_get_main_queue(), {
                self.hideNotification(tap)
            })
//        }
    }
    
    func hideNotification(recognizer: UIGestureRecognizer) {
        if (self.view.subviews.contains(self.notificationView)) {
            self.notificationView.removeFromSuperview()
        }
    }
}


