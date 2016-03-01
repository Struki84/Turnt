//
//  PurchaseAccountView.swift
//  UITest
//
//  Created by Šimun on 26.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit
protocol PurchaseAccountViewDelegate {
    
    func showIAPPurchase(parentView: PurchaseAccountView) -> Void
}

@IBDesignable
class PurchaseAccountView: UIView {

    @IBOutlet weak var goToInAppPurchase: UIButton!

    var view: UIView!
    var delegate: PurchaseAccountViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        xibSetup()
        goToInAppPurchase.layer.borderWidth = 1
        goToInAppPurchase.layer.cornerRadius = 5
//        goToInAppPurchase.layer.borderColor = UIColor.whiteColor().CGColor
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        xibSetup()
        goToInAppPurchase.layer.borderWidth = 1
        goToInAppPurchase.layer.cornerRadius = 5
//        goToInAppPurchase.layer.borderColor = UIColor.whiteColor().CGColor
    }
    
    func xibSetup() {
        view = loadViewFromNib()
        view.frame = bounds
        view.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleHeight]
        addSubview(view)
    }
    
    func loadViewFromNib() -> UIView {
        let bundle = NSBundle(forClass: self.dynamicType)
        let nib = UINib(nibName: "PurchaseAccountView", bundle: bundle)
        let view = nib.instantiateWithOwner(self, options: nil)[0] as! UIView
        return view
    }
    
    @IBAction func goToInAppPurchasePress(sender: AnyObject) {
        self.delegate?.showIAPPurchase(self)
        
    }
    
    
  
}
