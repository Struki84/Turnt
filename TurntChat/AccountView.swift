//
//  AccountView.swift
//  UITest
//
//  Created by Šimun on 25.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit

@IBDesignable
class AccountView: UIView {
    
    var view: UIView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var accountImage: UIImageView!
    @IBOutlet weak var notificationLabel: UILabel!
    
    @IBInspectable var title: String? {
        get {
            return titleLabel.text
        }
        set(title) {
            titleLabel.text = title
        }
    }
    
    @IBInspectable var image: UIImage? {
        get {
            return accountImage.image
        }
        set(image) {
            accountImage.image = image
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        xibSetup()
        notificationLabel.layer.masksToBounds = true
        notificationLabel.layer.borderColor = UIColor.whiteColor().CGColor
        notificationLabel.layer.borderWidth = 1
        notificationLabel.layer.cornerRadius = 12
        
        accountImage.layer.cornerRadius = accountImage.frame.size.width / 2;
        accountImage.clipsToBounds = true
        notificationLabel.hidden = true
        view.backgroundColor = UIColor.TurntPink()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        xibSetup()
        notificationLabel.layer.borderColor = UIColor.whiteColor().CGColor
        notificationLabel.layer.borderWidth = 1
        notificationLabel.layer.cornerRadius = 12
        
        accountImage.layer.cornerRadius = accountImage.frame.size.width / 2;
        accountImage.clipsToBounds = true
        notificationLabel.hidden = true        
    }
    
    func xibSetup() {
        view = loadViewFromNib()
        view.frame = bounds
        view.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleHeight]
        addSubview(view)
    }
    
    func loadViewFromNib() -> UIView {
        let bundle = NSBundle(forClass: self.dynamicType)
        let nib = UINib(nibName: "AccountView", bundle: bundle)
        let view = nib.instantiateWithOwner(self, options: nil)[0] as! UIView
        return view
    }
    
}



