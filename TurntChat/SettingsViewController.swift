
//
//  SettingsViewController.swift
//  FlowTest
//
//  Created by Šimun on 09.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UIImagePickerControllerDelegate {
    
    @IBOutlet weak var settingsTableView: UITableView!
    @IBOutlet weak var settingsAccountView: AccountView!
    @IBOutlet weak var passwordTextFiled: UITextField!

    var account: Account?
    var accounts: [Account] = []
    var accountId: NSNumber = 0.0
    var deleting: Bool?
    
    let apiRequest: ApiRequest = ApiRequest()
    let imagePicker: UIImagePickerController = UIImagePickerController()
    var searchableSwitch: UISwitch?
    
    override func viewWillAppear(animated: Bool) {
        settingsAccountView.frame.size.width = UIScreen.mainScreen().bounds.width
        
        let accountViewFrame: CGRect = CGRect(
            x: 0,
            y: 0,
            width: self.view.frame.size.width,
            height: 225
        )
        let accountView: AccountView = AccountView(frame: accountViewFrame)
        
        accountView.view.backgroundColor = UIColor.TurntPink()
        accountView.titleLabel.text = account?.username
        
        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:Selector("imageTapped:"))
        accountView.accountImage.addGestureRecognizer(tapGestureRecognizer)
        accountView.accountImage.userInteractionEnabled = !account!.isImageAddedByUser()
        accountView.image = account?.getImage()
        
        settingsAccountView.addSubview(accountView)
    }
    
    override func viewWillDisappear(animated: Bool) {
        if (deleting == true) {
            print("deleting account")
        } else {
            updateAccount()
            print("update account")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        account = Account.get(accountId)
        let contentSize = UIScreen.mainScreen().bounds
        searchableSwitch = UISwitch.init(frame: CGRectMake(contentSize.width - 60, 6, 0, 0))
        if(account!.visible.boolValue) {
            searchableSwitch?.setOn(true, animated: true)
        } else {
            searchableSwitch?.setOn(false, animated: true)
        }
        searchableSwitch!.addTarget(self, action: Selector("stateChanged:"), forControlEvents: UIControlEvents.ValueChanged)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.Plain, target: nil, action: nil)
        
        settingsTableView.delegate = self
        settingsTableView.dataSource = self
        settingsTableView.backgroundColor = UIColor.TurntLightGray()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "requestTimeout", name: RequestNotification, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func stateChanged(switchState: UISwitch) {
        if (searchableSwitch!.on) {
            print("switch on")
            account!.visible = 1
        } else {
            print("switch off")
            account!.visible = 0
        }
    }
    
    //MARK: - Table View Delegate methods
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 48
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = settingsTableView.dequeueReusableCellWithIdentifier("SettingsCell", forIndexPath: indexPath) as UITableViewCell
        
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        cell.textLabel?.font = UIFont.systemFontOfSize(15)
        let cellContentFrame = cell.contentView.frame
        let margin: CGFloat = 15
        let passwordTextFieldFrame = CGRectMake(margin, 0, cellContentFrame.width - margin, cellContentFrame.height)
        
        switch (indexPath.row) {
        case 0:
            cell.textLabel!.text = "Change profile picture"
            break
        case 1:
            cell.textLabel!.text = "Searchable by username"
            cell.contentView.addSubview(searchableSwitch!)
            break
        case 2:
            passwordTextFiled = UITextField.init(frame: passwordTextFieldFrame)
            passwordTextFiled.font = UIFont.systemFontOfSize(15)
            if (account!.password != "") {
                passwordTextFiled.placeholder = "●●●●●●●"
            } else {
                passwordTextFiled.placeholder = "Set password to claim username"
            }
            passwordTextFiled.secureTextEntry = true
            passwordTextFiled.tintColor = UIColor.TurntPink()
            passwordTextFiled.delegate = self
            cell.contentView.addSubview(passwordTextFiled)
            break
        case 3:
            cell.textLabel!.text = "Delete profile and all contacts"
            cell.textLabel!.textColor = UIColor.TurntPink()
            break
        default:
            print("print")
        }
        
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch (indexPath.row) {
        case 0:
            imageTapped(self)
        case 3:
            print("delete account: account_id = \(account!.id) ")
            deleting = true
            showDeleteConfirmationAlert()
            break
        default:
            print("cell selected at index: \(indexPath.row)")
        }
    }
    
    func updateAccount() {
        let requestBody: [String:String] = [
            "account_id": "\(self.accountId)",
            "username" : "\(account!.username)",
            "password" : "\(account!.password)",
            "active" : "\(account!.active)",
            "visible" : "\(account!.visible)",
            "image" : account!.image.base64EncodedStringWithOptions([])
        ]
        
        apiRequest.updateAccount(requestBody) { (success, accountUpdated, userAccounts, responseBody, error) -> Void in
            if success {
                if let updated = accountUpdated {
                    if updated {
                        Account.syncRecords(userAccounts)
                    }
                }
            }
        }
    }
    
    func showAlert(title: String? ,content: String?){
        let alertController = UIAlertController(
            title: title,
            message: content,
            preferredStyle: UIAlertControllerStyle.Alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default,handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func showDeleteConfirmationAlert() {
        let alertController = UIAlertController(
            title: "Are you sure?".localized,
            message: "This account will be deleted permanently...".localized,
            preferredStyle: UIAlertControllerStyle.Alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: {(action : UIAlertAction!) in
            let requestBody: [String: String] = [
                "account_id": "\(self.account!.id)"
            ]
            self.account!.remove()
            self.accounts = Account.all()
            print("all accounts after delete: \(self.accounts)")
            
            self.apiRequest.deleteAccount(requestBody, completionHandler: { (success, accountDeleted, responseBody, error) -> Void in
                print("setting deleteAccount responseBody: \(responseBody)")
                if success {
                    if accountDeleted {
                        print("success with deleting account")
                        if (self.accounts.count > 0) {
                            print("delete1")
                            self.navigationController?.popToRootViewControllerAnimated(true)
                        } else {
                            print("delete2")
                            self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                        }
                    }
                }
            })
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func requestTimeout(){
        showAlert("Ooops! There was a problem!".localized ,content: ConfigManager.sharedInstance.alertMsg!["server_response_500"])
    }
    
    // MARK: - Text field delegate functions
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        print("password: \(passwordTextFiled.text!)")
        if passwordTextFiled.text!.characters.count > 5 {
            self.account!.password = passwordTextFiled.text!
            self.account!.save()
        } else {
            showAlert("Password to short".localized, content: "Use at least 6 characters".localized)
            print("password is to short")
        }
        
        view.endEditing(true)
        return true
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : AnyObject]!) {
        self.dismissViewControllerAnimated(true, completion: { () -> Void in
            self.account!.image = UIImageJPEGRepresentation(image, 0.5)!
            self.account!.save()
            self.viewWillAppear(true)
            self.viewDidLoad()
        })
    }
    
    func imageTapped(img: AnyObject)
    {
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
}
