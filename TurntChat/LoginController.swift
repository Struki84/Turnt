//
//  ViewController.swift
//  FlowTest
//
//  Created by Šimun on 09.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit
import CoreData

let RequestNotification = "com.release.1.0.0b1.requestTimeout"

class LoginController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var enterButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var hintLabel: UILabel!
    
    let apiRequest = ApiRequest()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        usernameTextField.delegate = self
        loadingIndicator.hidden = true
        usernameTextField.tintColor = UIColor.TurntPink()
        hintLabel.text = "CHOOSE USERNAME".localized
        enterButton.setTitle("ENTER".localized, forState: UIControlState.Normal)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "requestTimeout", name: RequestNotification, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    @IBAction func enterTurnt(sender: AnyObject) {
        if usernameTextField.text!.isEmpty {
            showAlert(ConfigManager.sharedInstance.alertMsg!["missing_username"])
        }
        else{
            enterButton.enabled = false
            
            loadingIndicator.hidden = false
            loadingIndicator.startAnimating()
            let defaults = NSUserDefaults.standardUserDefaults()
            let deviceId: String! = defaults.objectForKey("deviceToken") as! String
            
            let requestBody : [String:String] = [
                    "username"  : usernameTextField.text!,
                    "deviceId"  : deviceId]

            self.apiRequest.login(requestBody, completionHandler: { (success, logedIn, responseBody, error) -> Void in
                
                ConfigManager.sharedInstance.hashToken = responseBody["token"].stringValue
                defaults.setObject(ConfigManager.sharedInstance.hashToken, forKey: "hashToken")

                if success {
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.hidden = true
                    if logedIn == true {
                        print("Login success!")
                        NSUserDefaults.standardUserDefaults().setValue(self.usernameTextField.text!, forKey: "loginAs")
                        Account.syncRecords(responseBody["accounts"])
                        self.performSegueWithIdentifier("EnterTurnt", sender: sender)
                        self.usernameTextField.text = ""
                        self.updateStatus("online")
                    }
                    else {
                        self.showAlertWithTextField("'\(self.usernameTextField.text!)' is already taken. Try something else or use password.".localized)
                        print("Login failed! if logedIn")
                    }
                }
                else {
                    self.showAlert("Something went wrong ;(".localized)
                    print("Login failed! if not success")
                }
                
                self.enterButton.enabled = true
            })
        }
    }
    
    func showAlertWithTextField(content: String?) {
        let alertController = UIAlertController(
            title: "Can't Login",
            message: content,
            preferredStyle: UIAlertControllerStyle.Alert
        )
        var passwordTextField: UITextField?
        alertController.addTextFieldWithConfigurationHandler { textField -> Void in
            passwordTextField = textField
        }
        alertController.addAction(UIAlertAction(title: "Use password", style: UIAlertActionStyle.Default,handler: { (UIAlertAction) in
            print("use password pressed, password from textField: \(passwordTextField!.text!)")
            if (passwordTextField!.text!.characters.count > 5) {
                
                let requestBody : [String:String] = [
                    "username"  : "\(self.usernameTextField.text!)",
                    "password"  : "\(passwordTextField!.text!)"]
                
                self.apiRequest.recoveryAccount(requestBody, completionHandler: { (success, logedIn, responseBody, error) -> Void in
                    ConfigManager.sharedInstance.hashToken = responseBody["token"].stringValue
                    let defaults = NSUserDefaults.standardUserDefaults()
                    defaults.setObject(ConfigManager.sharedInstance.hashToken, forKey: "hashToken")
                    if success {
                        self.loadingIndicator.stopAnimating()
                        self.loadingIndicator.hidden = true
                        if logedIn == true {
                            print("Login success!")
                            NSUserDefaults.standardUserDefaults().setValue(self.usernameTextField.text!, forKey: "loginAs")
                            Account.syncRecords(responseBody["accounts"])
                            self.performSegueWithIdentifier("EnterTurnt", sender: self)
                            self.usernameTextField.text = ""
                        }
                        else {
                            self.showAlertWithTextField("'\(self.usernameTextField.text!)' is already taken. Try something else or use password.".localized)
                            print("Login failed! if logedIn")
                        }
                    }
                    else {
                        self.showAlert("Something went wrong ;(".localized)
                        print("Login failed! if not success")
                    }
                })
            } else {
                self.showAlert("Wrong password".localized)
            }
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default,handler: nil))
        
        self.presentViewController(alertController, animated: true, completion: nil)
        self.loadingIndicator.hidden = true
        self.loadingIndicator.stopAnimating()
    }
    
    func showAlert(content: String?) {
        let alertController = UIAlertController(
            title: "Can't Login",
            message: content,
            preferredStyle: UIAlertControllerStyle.Alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default,handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
        self.loadingIndicator.hidden = true
        self.loadingIndicator.stopAnimating()
    }
    
    func requestTimeout() {
        showAlert(ConfigManager.sharedInstance.alertMsg!["server_response_500"])
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        usernameTextField.resignFirstResponder()
        return true
    }
    
    func updateStatus(status: String) {
        self.apiRequest.updateStatus(["status": "\(status)"], completionHandler: { (success, responseBody, error) -> Void in
            print("update status: \(success)")
            if success {
                print("status updated with success for account \(responseBody)")
            }
        })
    }
}

