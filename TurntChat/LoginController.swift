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
        loadingIndicator.isHidden = true
        usernameTextField.tintColor = UIColor.TurntPink()
        hintLabel.text = "CHOOSE USERNAME".localized
        enterButton.setTitle("ENTER".localized, for: UIControlState())
        
        NotificationCenter.default.addObserver(self, selector: #selector(LoginController.requestTimeout), name: NSNotification.Name(rawValue: RequestNotification), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    @IBAction func enterTurnt(_ sender: AnyObject) {
        if usernameTextField.text!.isEmpty {
            showAlert(ConfigManager.sharedInstance.alertMsg!["missing_username"])
        }
        else{
            enterButton.isEnabled = false
            
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimating()
            let defaults = UserDefaults.standard
            let deviceId: String! = defaults.object(forKey: "deviceToken") as! String
            
            let requestBody : [String:String] = [
                    "username"  : usernameTextField.text!,
                    "deviceId"  : deviceId]

            self.apiRequest.login(requestBody, completionHandler: { (success, logedIn, responseBody, error) -> Void in
                
                ConfigManager.sharedInstance.hashToken = responseBody["token"].stringValue
                defaults.set(ConfigManager.sharedInstance.hashToken, forKey: "hashToken")

                if success {
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.isHidden = true
                    if logedIn == true {
                        print("Login success!")
                        UserDefaults.standard.setValue(self.usernameTextField.text!, forKey: "loginAs")
                        Account.syncRecords(responseBody["accounts"])
                        self.performSegue(withIdentifier: "EnterTurnt", sender: sender)
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
                
                self.enterButton.isEnabled = true
            })
        }
    }
    
    func showAlertWithTextField(_ content: String?) {
        let alertController = UIAlertController(
            title: "Can't Login",
            message: content,
            preferredStyle: UIAlertControllerStyle.alert
        )
        var passwordTextField: UITextField?
        alertController.addTextField { textField -> Void in
            passwordTextField = textField
        }
        alertController.addAction(UIAlertAction(title: "Use password", style: UIAlertActionStyle.default,handler: { (UIAlertAction) in
            print("use password pressed, password from textField: \(passwordTextField!.text!)")
            if (passwordTextField!.text!.characters.count > 5) {
                
                let requestBody : [String:String] = [
                    "username"  : "\(self.usernameTextField.text!)",
                    "password"  : "\(passwordTextField!.text!)"]
                
                self.apiRequest.recoveryAccount(requestBody, completionHandler: { (success, logedIn, responseBody, error) -> Void in
                    ConfigManager.sharedInstance.hashToken = responseBody["token"].stringValue
                    let defaults = UserDefaults.standard
                    defaults.set(ConfigManager.sharedInstance.hashToken, forKey: "hashToken")
                    if success {
                        self.loadingIndicator.stopAnimating()
                        self.loadingIndicator.isHidden = true
                        if logedIn == true {
                            print("Login success!")
                            UserDefaults.standard.setValue(self.usernameTextField.text!, forKey: "loginAs")
                            Account.syncRecords(responseBody["accounts"])
                            self.performSegue(withIdentifier: "EnterTurnt", sender: self)
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
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default,handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
        self.loadingIndicator.isHidden = true
        self.loadingIndicator.stopAnimating()
    }
    
    func showAlert(_ content: String?) {
        let alertController = UIAlertController(
            title: "Can't Login",
            message: content,
            preferredStyle: UIAlertControllerStyle.alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default,handler: nil))
        self.present(alertController, animated: true, completion: nil)
        self.loadingIndicator.isHidden = true
        self.loadingIndicator.stopAnimating()
    }
    
    func requestTimeout() {
        showAlert(ConfigManager.sharedInstance.alertMsg!["server_response_500"])
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        usernameTextField.resignFirstResponder()
        return true
    }
    
    func updateStatus(_ status: String) {
        self.apiRequest.updateStatus(["status": "\(status)"], completionHandler: { (success, responseBody, error) -> Void in
            print("update status: \(success)")
            if success {
                print("status updated with success for account \(responseBody)")
            }
        })
    }
}
