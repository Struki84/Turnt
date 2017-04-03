
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
    
    override func viewWillAppear(_ animated: Bool) {
        settingsAccountView.frame.size.width = UIScreen.main.bounds.width
        
        let accountViewFrame: CGRect = CGRect(
            x: 0,
            y: 0,
            width: self.view.frame.size.width,
            height: 225
        )
        let accountView: AccountView = AccountView(frame: accountViewFrame)
        
        accountView.view.backgroundColor = UIColor.TurntPink()
        accountView.titleLabel.text = account?.username
        
        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(SettingsViewController.imageTapped(_:)))
        accountView.accountImage.addGestureRecognizer(tapGestureRecognizer)
        accountView.accountImage.isUserInteractionEnabled = !account!.isImageAddedByUser()
        accountView.image = account?.getImage()
        
        settingsAccountView.addSubview(accountView)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
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
        let contentSize = UIScreen.main.bounds
        searchableSwitch = UISwitch.init(frame: CGRect(x: contentSize.width - 60, y: 6, width: 0, height: 0))
        if(account!.visible.boolValue) {
            searchableSwitch?.setOn(true, animated: true)
        } else {
            searchableSwitch?.setOn(false, animated: true)
        }
        searchableSwitch!.addTarget(self, action: #selector(SettingsViewController.stateChanged(_:)), for: UIControlEvents.valueChanged)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.plain, target: nil, action: nil)
        
        settingsTableView.delegate = self
        settingsTableView.dataSource = self
        settingsTableView.backgroundColor = UIColor.TurntLightGray()

        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.requestTimeout), name: NSNotification.Name(rawValue: RequestNotification), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func stateChanged(_ switchState: UISwitch) {
        if (searchableSwitch!.isOn) {
            print("switch on")
            account!.visible = 1
        } else {
            print("switch off")
            account!.visible = 0
        }
    }
    
    //MARK: - Table View Delegate methods
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 48
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = settingsTableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath) as UITableViewCell
        
        cell.selectionStyle = UITableViewCellSelectionStyle.none
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
        let cellContentFrame = cell.contentView.frame
        let margin: CGFloat = 15
        let passwordTextFieldFrame = CGRect(x: margin, y: 0, width: cellContentFrame.width - margin, height: cellContentFrame.height)
        
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
            passwordTextFiled.font = UIFont.systemFont(ofSize: 15)
            if (account!.password != "") {
                passwordTextFiled.placeholder = "●●●●●●●"
            } else {
                passwordTextFiled.placeholder = "Set password to claim username"
            }
            passwordTextFiled.isSecureTextEntry = true
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
            "image" : account!.image.base64EncodedString(options: [])
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
    
    func showAlert(_ title: String? ,content: String?){
        let alertController = UIAlertController(
            title: title,
            message: content,
            preferredStyle: UIAlertControllerStyle.alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default,handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func showDeleteConfirmationAlert() {
        let alertController = UIAlertController(
            title: "Are you sure?".localized,
            message: "This account will be deleted permanently...".localized,
            preferredStyle: UIAlertControllerStyle.alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default,handler: {(action : UIAlertAction!) in
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
                            self.navigationController?.popToRootViewController(animated: true)
                        } else {
                            print("delete2")
                            self.presentingViewController?.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            })
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func requestTimeout(){
        showAlert("Ooops! There was a problem!".localized ,content: ConfigManager.sharedInstance.alertMsg!["server_response_500"])
    }
    
    // MARK: - Text field delegate functions
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [AnyHashable: Any]!) {
        self.dismiss(animated: true, completion: { () -> Void in
            self.account!.image = UIImageJPEGRepresentation(image, 0.5)!
            self.account!.save()
            self.viewWillAppear(true)
            self.viewDidLoad()
        })
    }
    
    func imageTapped(_ img: AnyObject)
    {
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
}
