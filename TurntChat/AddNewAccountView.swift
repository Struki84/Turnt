//
//  AddNewAccountView.swift
//  UITest
//
//  Created by Šimun on 26.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit

protocol AddNewAccountDelegate {

    func addNewAccount(_ parentView: AddNewAccountView, inputUsername: String) -> Bool
}

@IBDesignable
class AddNewAccountView: UIView, UITextFieldDelegate {

    @IBOutlet weak var newAccountUsernameField: UITextField!
    @IBOutlet weak var addNewAccountButton: UIButton!
    
    var view: UIView!
    var delegate: AddNewAccountDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        xibSetup()
        addNewAccountButton.layer.borderWidth = 1
        addNewAccountButton.layer.cornerRadius = 5
        addNewAccountButton.layer.borderColor = UIColor.white.cgColor
        newAccountUsernameField.delegate = self
        view.backgroundColor = UIColor.TurntPink()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        xibSetup()
        addNewAccountButton.layer.borderWidth = 1
        addNewAccountButton.layer.cornerRadius = 5
        addNewAccountButton.layer.borderColor = UIColor.white.cgColor
        newAccountUsernameField.delegate = self
    }
    
    func xibSetup() {
        view = loadViewFromNib()
        view.frame = bounds
        view.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        addSubview(view)
    }
    
    func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "AddNewAccountView", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        return view
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        newAccountUsernameField.resignFirstResponder()
        return true
    }
    
    @IBAction func addNewAccountButtonPress(_ sender: AnyObject) {
        "add new account button pressed"
        if (self.delegate?.addNewAccount(self, inputUsername: newAccountUsernameField.text!) != nil) {
            newAccountUsernameField.resignFirstResponder()
            newAccountUsernameField.text = ""
            newAccountUsernameField.placeholder = "new username"
        }
    }
    
}
