//
//  FriendTableViewCell.swift
//  Relase.1.0.0.b1
//
//  Created by Šimun on 28.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit

protocol FriendTableViewCellDelegate {
    func approveFriend(button: UIButton) -> Void
}

@IBDesignable
class FriendTableViewCell: UITableViewCell {
    
    @IBOutlet weak var friendProfileImageView: UIImageView!
    @IBOutlet weak var friendUsername: UILabel!
    @IBOutlet weak var connectionStatusLabel: UILabel!
    @IBOutlet weak var connectionStatusImageView: UIImageView!
    @IBOutlet weak var approveFriendButton: UIButton!
    
    @IBInspectable var profileImage: UIImage? {
        get {
            return friendProfileImageView.image
        }
        
        set(profileImage) {
            friendProfileImageView.image = profileImage
        }
    }
    
    @IBInspectable var username: String? {
        get {
            return friendUsername.text
        }
        
        set(username) {
            friendUsername.text = username
        }
    }
    
    @IBInspectable var status: String? {
        get {
            return connectionStatusLabel.text
        }
        set(status) {
            connectionStatusLabel.text = status
        }
    }
    
    @IBInspectable var statusImage: UIImage? {
        get {
            return connectionStatusImageView.image
        }
        set(statusImage) {
            connectionStatusImageView.image = statusImage
        }
    }
    
    var view: UIView!
    var delegate: FriendTableViewCellDelegate?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String!) {
        super.init(style: UITableViewCellStyle.Value1, reuseIdentifier: reuseIdentifier)
        xibSetup()
        friendProfileImageView.layer.cornerRadius = friendProfileImageView.frame.size.width / 2;
        friendProfileImageView.clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        xibSetup()
        friendProfileImageView.layer.cornerRadius = friendProfileImageView.frame.size.width / 2;
        friendProfileImageView.clipsToBounds = true
    }
    
    func xibSetup() {
        view = loadViewFromNib()
        view.frame = bounds
        view.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleHeight]
        addSubview(view)
    }
    
    func loadViewFromNib() -> UIView {
        let bundle = NSBundle(forClass: self.dynamicType)
        let nib = UINib(nibName: "FriendTableCellView", bundle: bundle)
        let view = nib.instantiateWithOwner(self, options: nil)[0] as! UIView
        return view
    }
    
    @IBAction func approveFriendRequest(sender: AnyObject) {
        let button: UIButton = sender as! UIButton
        self.delegate?.approveFriend(button)
    }

}
