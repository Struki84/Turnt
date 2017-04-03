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
    override func viewDidAppear(_ animated: Bool) {
//        friendsTableView.reloadData()
        self.reloadFriendsTable()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addInfoView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(HomeViewController.requestTimeout), name: NSNotification.Name(rawValue: RequestNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HomeViewController.displayNotification(_:)), name: NSNotification.Name(rawValue: "pushNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HomeViewController.becameActive), name: NSNotification.Name(rawValue: "appIsActive"), object: nil)
        
        friendsTableView.delegate = self
        friendsTableView.dataSource = self
        friendsTableView.separatorColor = UIColor.TurntLightGray()
        
        let image = UIImage(named: "LOGO3")
        let imageView = UIImageView(image: image)
        self.navigationItem.titleView = imageView
        
        //TODO might be as UINavigationBar extension
        let navigationBar = self.navigationController?.navigationBar
        navigationBar?.setBackgroundImage(UIImage(), for: UIBarPosition.any, barMetrics: UIBarMetrics.default)
        navigationBar?.shadowImage = UIImage()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.plain, target: nil, action: nil)
        
        accountScrollView.backgroundColor = UIColor.TurntPink()
        
        // set up the refresh control
        self.refreshControl.addTarget(self, action: #selector(HomeViewController.refresh(_:)), for: UIControlEvents.valueChanged)
        self.friendsTableView.addSubview(refreshControl)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
        self.accounts = Account.all()
        
        if(firstTimeAfterLogin) {
            var numAco = 0
            for aco in self.accounts! {
                numAco += 1
                if (aco == Account.findByUsername(UserDefaults.standard.value(forKey: "loginAs")! as! String)) {
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
        self.accountScrollView.contentSize = CGSize(width: accountScrollViewWidth, height: self.accountScrollView.frame.size.height)
        self.accountScrollView.delegate = self
        
        for subview in self.accountScrollView.subviews{
            subview.removeFromSuperview()
        }
        
        for i in 0 ..< numberOffAccountViews {
            self.createAccountView(i)
        }
        
        let viewStartingPoint = CGPoint(x: CGFloat(currentAccountPage) * self.view.frame.size.width, y: 0)
        self.accountScrollView.setContentOffset(viewStartingPoint, animated: true)

        self.reloadFriendsTable()
    }
    
    //MARK: - Layout
    func addInfoView() {
        let infoViewX: CGFloat = (self.view.frame.size.width - 320)/2
        let calculatedTableViewHeight: CGFloat = self.view.frame.height - self.accountScrollView.frame.size.height - 66
        let infoViewY: CGFloat = (calculatedTableViewHeight-150)/2
        infoView = InfoView.init(frame: CGRect(x: infoViewX, y: infoViewY, width: 320, height: 150))
        self.friendsTableView.addSubview(infoView)
    }
    
    func createAccountView(_ atIndex: Int) {
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
                accountView.notificationLabel.isHidden = false
            }
            
            let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(HomeViewController.imageTapped(_:)))
            accountView.accountImage.isUserInteractionEnabled = !account.isImageAddedByUser()
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
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToChat" {
//            print("goToChat segue performing")
            let cell: UITableViewCell = sender as! UITableViewCell
            let ChatController = segue.destination as! ChatViewController
            ChatController.friendId = (accounts![currentAccountPage].friends.allObjects[cell.tag] as AnyObject).id as Int?
            ChatController.accountId = currentAccountId
            
//            let account: Account = accounts![currentAccountPage]
//            account.resetNotifications()
        }
        else if segue.identifier == "goToSettings" {
//            print("Page \(self.currentAccountPage), id : \(accounts![currentAccountPage].id)")
            let SettingsController = segue.destination as! SettingsViewController
            SettingsController.accountId = accounts![currentAccountPage].id as NSNumber
        }
        else if segue.identifier == "goToSearch" {
//            print("goToSearch segue performing")
            let SearchController = segue.destination as! SearchViewController
            SearchController.accountId = accounts![currentAccountPage].id as NSNumber
        }
    }
    
    func refresh(_ sender: AnyObject) {
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
    
    func addNewAccount(_ parentView: AddNewAccountView, inputUsername: String) -> Bool {
        apiRequest.createAccount(["username" : inputUsername], completionHandler: { (success, accountCreated, userAccounts, responseBody, error) -> Void in
            if success {
                print("Account Created")
                Account.create(responseBody["account"], completed: {_ in })
                self.accounts = Account.all()
                UIView.animate(withDuration: 0.4, animations: { () -> Void in
                    if self.accounts!.count == ConfigManager.sharedInstance.maxAllowedAccounts! - 1 {
                        parentView.removeFromSuperview()
                    }
                    else {
                        self.accountScrollView.contentSize = CGSize(width: self.accountScrollView.contentSize.width + self.view.frame.width, height:self.accountScrollView.frame.size.height)
                        parentView.frame.origin.x += self.view.frame.width
                    }
                    }, completion: { (completed) -> Void in
                        self.navigationItem.rightBarButtonItem?.isEnabled = true
                        self.navigationItem.leftBarButtonItem?.isEnabled = true
                        self.viewWillAppear(true)
                        self.accounts = Account.all()
                        self.createAccountView(self.accounts!.count - 1)
                        let viewStartingPoint = CGPoint(x: CGFloat(self.accounts!.count - 1) * self.view.frame.size.width, y: 0)
                        self.accountScrollView.setContentOffset(viewStartingPoint, animated: true)
//                        self.friendsTableView.reloadData()
                        self.reloadFriendsTable()
                })
            }
        })
        return true
    }
    
    //TODO: debug this method
    func approveFriend(_ button: UIButton) {
        print("homeVC approveFriend button pressed")
        
        let approvedFriend: Friend = accounts![currentAccountPage].friends.allObjects[button.tag] as! Friend
        let requestBody: [String: String] = [
            "target_account_id": "\(approvedFriend.id)",
            "account_id": "\(currentAccountId!)"
        ]
        button.isEnabled = false
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
    
    func imageTapped(_ img: AnyObject) {
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.sourceType = UIImagePickerControllerSourceType.savedPhotosAlbum
        imagePicker.navigationBar.barTintColor = UIColor.TurntPink()
        imagePicker.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.white]
        imagePicker.navigationBar.tintColor = UIColor.white
        imagePicker.navigationBar.barStyle = .black
        imagePicker.navigationBar.isTranslucent = false
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.savedPhotosAlbum){
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [AnyHashable: Any]!) {
        self.dismiss(animated: true, completion: { () -> Void in
            
            self.accounts![self.currentAccountPage].image = UIImageJPEGRepresentation(image, 0.5)!
            self.accounts![self.currentAccountPage].save()
            
            self.createAccountView(self.currentAccountPage)
            
            let accountToUpdate = self.accounts![self.currentAccountPage]
            
            let requestBody: [String:String] = [
                "account_id": "\(accountToUpdate.id)",
                "username"  : "\(accountToUpdate.username)",
                "active"    : "\(accountToUpdate.active)",
                "visible"   : "\(accountToUpdate.visible)",
                "image"     : accountToUpdate.image.base64EncodedString(options: []),
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
    
    func displayNotification(_ n: Notification) {
        reloadFriendsTable()
        let nData = n.userInfo!["aps"] as! NSDictionary
        let alert = nData.value(forKey: "alert")
        if (alert != nil) {
            displayNotificationWithText(alert as! String)
        }
    }
    
    //MARK: - Table View Delegate methods
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var friendsCount: Int = 0
        if currentAccountPage < self.accounts!.count {
            if let account = accounts?[currentAccountPage] {
                friendsCount = account.friends.count
            }
        }
        
        if (friendsCount > 0) {
            infoView.isHidden = true
        } else {
            infoView.isHidden = false
        }
        
        return friendsCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let row = indexPath.row
        let cell = friendsTableView.dequeueReusableCell(withIdentifier: "FriendCell", for: indexPath) as! FriendTableViewCell
        let friends = accounts![currentAccountPage].friends.allObjects
        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsets.zero
        cell.layoutMargins = UIEdgeInsets.zero
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
                    cell.approveFriendButton.setBackgroundImage(UIImage(named: "PLUS"), for: UIControlState())
                    cell.approveFriendButton.isHidden = false
                    cell.approveFriendButton.isEnabled = true
                }
                else {
                    cell.approveFriendButton.isHidden = true
                }
            }
            else {
                cell.approveFriendButton.isHidden = false
                cell.approveFriendButton.isEnabled = true
                if (friend.poked_me as Bool) {
                    cell.approveFriendButton.setBackgroundImage(UIImage(named: "NOTIFICATION1"), for: UIControlState())
                } else {
                    cell.approveFriendButton.setBackgroundImage(UIImage(named: "NOTIFICATION2"), for: UIControlState())
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = friendsTableView.dequeueReusableCell(withIdentifier: "FriendCell", for: indexPath) as! FriendTableViewCell
        cell.tag = indexPath.row
        
        let friends = accounts![currentAccountPage].friends.allObjects
        let friend = friends[indexPath.row] as! Friend
        if (friend.confirmed == 1) {
            performSegue(withIdentifier: "goToChat", sender: cell)
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .normal, title: "Delete") { (rowAction:UITableViewRowAction, indexPath:IndexPath) -> Void in
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
                tableView.deleteRows(at: [indexPath], with: .left)
        }
        deleteAction.backgroundColor = UIColor.TurntPink()
        return [deleteAction]
    }
    
    //MARK: - Scroll View Delegate methods
    func scrollViewDidScroll(_ scrollView: UIScrollView) {

        if(firstTimeAfterLogin) {
            self.firstTimeAfterLogin = false
        } else {
            if scrollView == accountScrollView {
                let width = scrollView.frame.size.width;
                let page = Int((scrollView.contentOffset.x + (0.5 * width)) / width);
                if (self.currentAccountPage != page) {
                    self.currentAccountPage = page
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.navigationItem.leftBarButtonItem?.isEnabled = true

                    if page < self.accounts!.count {
                        currentAccountId = accounts![page].id as Int?
                    }
                    else {
                        self.navigationItem.rightBarButtonItem?.isEnabled = false
                        self.navigationItem.leftBarButtonItem?.isEnabled = false
                    }
//                    friendsTableView.reloadData()
                    self.reloadFriendsTable()
                }
            }
        }
    }
    
    //MARK: - Helpers
    func showIAPPurchase(_ parentView: PurchaseAccountView) {
        let alertController = UIAlertController(
            title: "Purchase more accounts!",
            message: "In App Purchase is not enabled at the moment, It will be available in the next beta realese",
            preferredStyle: UIAlertControllerStyle.alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default,handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func showAlert(_ content: String?){
        let alertController = UIAlertController(
            title: "Ooops! There was a problem!",
            message: content,
            preferredStyle: UIAlertControllerStyle.alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default,handler: nil))
        self.present(alertController, animated: true, completion: nil)
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
    func displayNotificationWithText(_ text: String) {
//        if (!self.view.subviews.contains(self.notificationView)) {
            self.notificationView = UITextView.init(frame: CGRect(x: 0, y: -msgHeight, width: self.view.frame.size.width, height: msgHeight))
            self.notificationView.text = text
            self.notificationView.isUserInteractionEnabled = false
            self.notificationView.textAlignment = .center
            self.notificationView.font = UIFont.systemFont(ofSize: 15)
            self.notificationView.isOpaque = true
            self.notificationView.textColor = UIColor.TurntPink()
            self.notificationView.backgroundColor = UIColor(white: 1, alpha: 0.7)
            let tap = UITapGestureRecognizer.init(target: self, action:#selector(HomeViewController.hideNotification(_:)))
            tap.delegate = self
            self.notificationView.addGestureRecognizer(tap)
            self.view.addSubview(notificationView)
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.7, options: [], animations: {
                self.notificationView.frame.origin.y += self.msgHeight
                }, completion: nil)
            let dispatchTime: DispatchTime = DispatchTime.now() + Double(Int64(5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
                self.hideNotification(tap)
            })
//        }
    }
    
    func hideNotification(_ recognizer: UIGestureRecognizer) {
        if (self.view.subviews.contains(self.notificationView)) {
            self.notificationView.removeFromSuperview()
        }
    }
}


