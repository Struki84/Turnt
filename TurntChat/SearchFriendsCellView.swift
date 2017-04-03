//
//  SearchFriendsCellView.swift
//  TurntChat
//
//  Created by Šimun on 21.07.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit
protocol SearchFriendsCellViewDelegate {
    
    func appendFriend(_ sender: AnyObject) -> Void
}

@IBDesignable
class SearchFriendsCellView: UITableViewCell {
    
    @IBOutlet weak var connectionStatusLabel: UILabel!
    @IBOutlet weak var connectionStatusImageView: UIImageView!
    @IBOutlet weak var friendProfileImageView: UIImageView!
    @IBOutlet weak var friendUsername: UILabel!
    @IBOutlet weak var addFriendButton: UIButton!
    
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
    var delegate: SearchFriendsCellViewDelegate?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String!) {
        super.init(style: UITableViewCellStyle.value1, reuseIdentifier: reuseIdentifier)
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
        view.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        addSubview(view)
    }

    
    func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "SearchFriendsViewCell", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        return view
    }

    @IBAction func addFriend(_ sender: AnyObject) {
        self.delegate?.appendFriend(sender)
    }
}
