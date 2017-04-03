//
//  ChatViewController.swift
//  FlowTest
//
//  Created by Šimun on 09.05.2015..
//  Copyright (c) 2015. Manifest Media ltd. All rights reserved.
//

import UIKit
import Starscream
import SwiftyJSON
import AVFoundation
import AVKit

class ChatViewController: UIViewController, UITextViewDelegate, WebSocketDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate {

    var inputContainerView: UIView!
    var enterMsgTextView: UITextField!
    var outcomingMsgContiner: UIView!
    var incomingMsgContainer: UIView!
    var sendButton: UIButton!
    var userImageView: UIImageView!
    var sendMediaButton: UIButton!
    var outcomingMsgView: UITextView!
    var friendImageView: UIImageView!
    var incomingMediaButton: UIButton!
    var incomingMsgView: UITextView!
    var statusView: UIImageView!
    var progressView: UIProgressView!

    var accountId: Int?
    var friendId: Int?
    var channelId: Int?
    var socket: WebSocket?
    let apiRequest: ApiRequest! = ApiRequest()
    let imagePicker: UIImagePickerController = UIImagePickerController()
    var photoMsgView: UIImageView!
    var photo: UIImage!
    var videoUrl: URL!
    let playerController = AVPlayerViewController()
    var displayingMediaMode: Bool = false

    var counter:Int = 0 {
        didSet {
            let fractionalProgress = Float(counter) / 100.0
            let animated = counter != 0
            progressView.setProgress(fractionalProgress, animated: animated)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dismissPoke()
        configureNavigationBarView()
        configureView()
        getChannelId()
        
        socket = WebSocket(url: (NSURL(scheme: "http", host:ConfigManager.sharedInstance.WebSocketUrl!, path: "/chat/\(channelId!)/\(accountId!)") as? URL)!)
        socket!.delegate = self
        socket!.connect()
        
        progressView.isHidden = true
        progressView.setProgress(0, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if (!displayingMediaMode) {
            self.socket!.disconnect()
        } else {
            print("displaying media")
        }
    }
    
    func dismissPoke() {
        let friend: Friend = Friend.get(friendId!)!
        let requestBody : [String:String] = [
            "id"        : "\(accountId!)",
            "buddy_id"  : "\(friend.friend_account_id)"]
        
        apiRequest.dismissPoke(requestBody, completionHandler: {(success, poked, responseBody, error) -> Void in
            if (success) {
                print("poke dismissed succesfully")
            }
            else {
                print("problem with dismissing poke")
            }
        })
    }
    
    func getChannelId() {
        let friend: Friend = Friend.get(friendId!)!
        if Int(friend.friend_account_id) > accountId! {
            let id: String = "\(accountId!)\(Int(friend.friend_account_id))"
            channelId = Int(id)
        } else {
            let id: String = "\(Int(friend.friend_account_id))\(accountId!)"
            channelId = Int(id)
        }
        print(channelId)
    }
    
    //MARK: UITextView delegate methods
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let maxHeight: CGFloat = 180.0
        let lineHeight = textView.font!.lineHeight
        let contentHeight = textView.contentSize.height
        var newViewHeight = contentHeight + lineHeight
        
        if text == "\n" {
            if newViewHeight > maxHeight {
                newViewHeight = maxHeight
            }
        }
        return true
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        let maxHeight: CGFloat = 180.0
        let lineHeight = textView.font!.lineHeight
        let contentHeight = textView.contentSize.height
        let newViewHeight = contentHeight + lineHeight
        if newViewHeight > maxHeight {
           
        }
    }
    
    //MARK: websocket delegate methods
    func websocketDidConnect(_ socket: WebSocket) {
        print("Chat connected \(socket)")
    }
    
    func websocketDidDisconnect(_ socket: WebSocket, error: NSError?) {
        print("Chat disconnected \(error?.localizedDescription)")
    }
    
    func websocketDidReceiveData(_ socket: WebSocket, data: Data) {
        print("Chat data transfer")
    }
    
    func websocketDidReceiveMessage(_ socket: WebSocket, text: String) {
        if let dataFromString = text.data(using: String.Encoding.utf8, allowLossyConversion: false) {
            let json = JSON(data: dataFromString)
            print("\(json["type"]) received")
            
            if json["type"].stringValue == "status" {
                print("Update user status: \(json)")
                if json["online"].stringValue == "true" {
                    statusView.isHidden = false
                    sendButton.setImage(UIImage(named: "SEND"), for: UIControlState())
                    sendButton.tag = 1
                    sendMediaButton.setImage(UIImage(named: "SEND-MEDIA"), for: UIControlState())
                    sendMediaButton.isEnabled = true
                } else {
                    statusView.isHidden = true
                    sendButton.setImage(UIImage(named: "POKE-BUTTON"), for: UIControlState())
                    sendButton.tag = 0
                    sendMediaButton.setImage(UIImage(named: "SEND-MEDIA-GRAY"), for: UIControlState())
                    sendMediaButton.isEnabled = false
                    incomingMediaButton.isEnabled = false
                }
            } else if json["type"].stringValue == "text" {
                incomingMsgView.text = json["content"].stringValue
                incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO-GRAY"), for: UIControlState())
                incomingMediaButton.isEnabled = false
                }
              else if json["type"].stringValue == "image" {
                if let image: String = json["content"].string {
                    let imgData: Data = Data(base64Encoded: image, options:NSData.Base64DecodingOptions(rawValue: 0))!
                    self.photo = UIImage(data: imgData)!
                }
                incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO"), for: UIControlState())
                incomingMediaButton.tag = 0
                incomingMediaButton.isEnabled = true
            }
            else if json["type"].stringValue == "video" {
                if let video: String = json["content"].string {
                    let videoData: Data = Data(base64Encoded: video, options:NSData.Base64DecodingOptions(rawValue: 0))!
                    let writePath: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("receivedMovie.mov")
                    try? videoData.write(to: writePath, options: [.atomic])
                    self.videoUrl = writePath
                }
                incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO"), for: UIControlState())
                incomingMediaButton.tag = 1
                incomingMediaButton.isEnabled = true
            }
        }
    }
    
    //MARK: buttons actions
    func cleanButtonPressed(_ sender: UIButton) {
        print("cleanButtonPressed")
        outcomingMsgView.text! = ""
        incomingMsgView.text! = ""
        enterMsgTextView.text! = ""
    }
    
    func sendButtonPressed(_ sender: UIButton) {
        print("send/poke ButtonPressed")
        if sender.tag == 1 {
            let dict = [ "content": "\(enterMsgTextView.text!)", "type" : "text"  ]
            let data = try? JSONSerialization.data(withJSONObject: dict, options: [])
            let string = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            socket!.writeString(string as! String)
            outcomingMsgView.text = enterMsgTextView.text!
            incomingMsgView.text = ""
            enterMsgTextView.text = ""
        } else {
            let friend: Friend = Friend.get(friendId!)!
            let requestBody : [String:String] = [
                "id"        : "\(accountId!)",
                "buddy_id"  : "\(friend.friend_account_id)"]

            apiRequest.poke(requestBody, completionHandler: {(success, poked, responseBody, error) -> Void in
                if (success) {
                    print("poke sent successfully")
                }
                else {
                    print("problem with poke")
                }
            })
        }
    }
    
    func incomingMediaButtonPressed(_ sender: UIButton) {
        displayingMediaMode = true
        print("incomingMediaButtonPressed")
        if sender.tag == 0 {
            self.showPhotoMsg()
            let dispatchTime: DispatchTime = DispatchTime.now() + Double(Int64(4 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
                self.hidePhotoMsg()
            })
        } else if sender.tag == 1 {
            self.showVideoMsg()
        }
    }
    
    func sendMediaButtonPressed(_ sender: UIButton) {
        displayingMediaMode = true
        print("sendMediaButtonPressed")
        presentActionSheet()
    }

    func presentActionSheet() {
        let actionSheet: UIAlertController = UIAlertController(title:nil, message:nil, preferredStyle:UIAlertControllerStyle.actionSheet)
        actionSheet.addAction(UIAlertAction(title:"Choose photo from library".localized, style:UIAlertActionStyle.default, handler:{ action in
            self.choosePhotoFromLibrery()
        }))
        actionSheet.addAction(UIAlertAction(title:"Take photo".localized, style:UIAlertActionStyle.default, handler:{ action in
            self.takePhoto()
        }))
        actionSheet.addAction(UIAlertAction(title:"Cancel".localized, style:UIAlertActionStyle.cancel, handler:nil))
        present(actionSheet, animated:true, completion:nil)
    }
    
    func choosePhotoFromLibrery() {
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

    func takePhoto() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            imagePicker.delegate = self
            imagePicker.sourceType = .camera
            let availableMediaTypes = UIImagePickerController.availableMediaTypes(for: .camera)
            imagePicker.mediaTypes = availableMediaTypes!
            imagePicker.videoMaximumDuration = 10.0
            self.present(imagePicker, animated: true, completion: nil)
        } else {
            print("camera not avaliable")
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let mediaType = info["UIImagePickerControllerMediaType"]!
        var dict: [String: String] = [:]
        
        if ((mediaType as AnyObject).isEqual("public.movie")) {
            //writing video to socket as string
            let videoUrl = info["UIImagePickerControllerMediaURL"] as! URL
            let video: Data = try! Data(contentsOf: videoUrl)
            let videoAsString: String = video.base64EncodedString(options: [])
            dict = ["content": "\(videoAsString)", "type" : "video"]
        }
        else if ((mediaType as AnyObject).isEqual("public.image")) {
            //writing image to socket as string
            let image: UIImage = info["UIImagePickerControllerOriginalImage"] as! UIImage
            let imageAsString: String = UIImageJPEGRepresentation(image, 0.1)!.base64EncodedString(options: [])
            dict = ["content": "\(imageAsString)", "type" : "image"]
        }
        
        let data = try? JSONSerialization.data(withJSONObject: dict, options: [])
        let string = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
        self.socket!.writeString(string as! String)
        
        //progress bar of sending (now fake)
        self.progressView.isHidden = false
        self.counter = 0
        for _ in 0..<100 {
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async(execute: {
                sleep(2)
                DispatchQueue.main.async(execute: {
                    if self.counter == 99 {
                        self.progressView.isHidden = true
                    } else {
                        self.counter += 1
                    }
                    return
                })
            })
        }
        
        self.sendMediaButton.isEnabled = true
        self.dismiss(animated: true, completion: nil)
        self.enterMsgTextView.becomeFirstResponder()
        displayingMediaMode = false
    }
    
    //MARK: view configuration
    func configureNavigationBarView() {
        let friend = Friend.get(friendId!)
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.plain, target: nil, action: nil)
        let cleanButton = UIBarButtonItem(title: "Clear".localized, style: UIBarButtonItemStyle.plain, target: self, action:#selector(ChatViewController.cleanButtonPressed(_:)))
        cleanButton.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: 15)], for: UIControlState())
        self.navigationItem.rightBarButtonItem = cleanButton
        
        let friendUsername: NSString = "\(friend!.username)"
        let friendUsernameSize = friendUsername.size(attributes: [NSFontAttributeName: UIFont.boldSystemFont(ofSize: 18)])
        
        let navBarTitleView = UIView.init(frame: CGRect(x: 0, y: 0, width: friendUsernameSize.width + 15, height: friendUsernameSize.height))
        
        let usernameLabel = UILabel.init(frame: CGRect(x: 10, y: 0, width: friendUsernameSize.width, height: friendUsernameSize.height))
        usernameLabel.text = "\(friend!.username)"
        usernameLabel.textColor = UIColor.TurntWhite()
        usernameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        
        statusView = UIImageView.init(frame: CGRect(x: 0, y: friendUsernameSize.height/2 - 4, width: 8, height: 8))
        statusView.backgroundColor = UIColor.TurntGreenLumo()
        statusView.layer.cornerRadius = 4
        statusView.clipsToBounds = true
        
        navBarTitleView.addSubview(usernameLabel)
        navBarTitleView.addSubview(statusView)

        self.navigationItem.titleView = navBarTitleView
    }
    
    func configureView() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let statusBarHeight: CGFloat = 20.0 //UIApplication.sharedApplication().statusBarFrame.size.height
        let navigationBarHeight: CGFloat = 44.0 //self.navigationController!.navigationBar.frame.size.height
        let keyboardHeight: CGFloat = 216.0
        let margin: CGFloat = 10.0
        var smallMargin: CGFloat = 8.0
        
        let inputContainerViewHeight: CGFloat = 40.0
        let inputContainerViewY = screenHeight - keyboardHeight - inputContainerViewHeight - statusBarHeight - navigationBarHeight
        let enterMsgTextViewHeight = inputContainerViewHeight/2
        let pokeButtonWidth: CGFloat = 60.0
        let pokeButtonHeight: CGFloat = 30.0
        let halfFreeScreenHeight = (screenHeight - keyboardHeight - inputContainerViewHeight - statusBarHeight - navigationBarHeight)/2
        var squareElementSide: CGFloat = 37.0
        if (halfFreeScreenHeight - 2*margin < 2*squareElementSide + smallMargin) { //adjust view to iPhone 4s
            squareElementSide = 27.0
            smallMargin = 5.0
        }
        
//progressView
        progressView = UIProgressView.init(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 10))
        progressView.progressTintColor = UIColor.TurntGreenLumo()
        progressView.backgroundColor = UIColor.clear
        self.view.addSubview(progressView)
        
//input Container
        inputContainerView = UIView.init(frame: CGRect(x: 0, y: inputContainerViewY, width: screenWidth, height: inputContainerViewHeight))
        inputContainerView.backgroundColor = UIColor.TurntWhite()
        self.view.addSubview(inputContainerView)
        
    //enterMsg
        enterMsgTextView = UITextField.init(frame: CGRect(x: margin, y: enterMsgTextViewHeight/2, width: screenWidth - pokeButtonWidth - 3*margin, height: enterMsgTextViewHeight))
        enterMsgTextView.backgroundColor = UIColor.TurntWhite()
        enterMsgTextView.font = UIFont.systemFont(ofSize: 15)
        enterMsgTextView.placeholder = "Enter message"
        enterMsgTextView.becomeFirstResponder()
        inputContainerView.addSubview(enterMsgTextView)
        
    //pokeButton
        sendButton = UIButton.init(frame: CGRect(x: enterMsgTextView.frame.size.width + 2*margin, y: (inputContainerViewHeight - pokeButtonHeight)/2, width: pokeButtonWidth, height: pokeButtonHeight))
        sendButton.setBackgroundImage(UIImage(named: "POKE-BUTTON"), for: UIControlState())
        sendButton.addTarget(self, action: #selector(ChatViewController.sendButtonPressed(_:)), for: UIControlEvents.touchUpInside)
        inputContainerView.addSubview(sendButton)
        
//msg Containers
    //outcoming container
        outcomingMsgContiner = UIView.init(frame: CGRect(x: margin, y: halfFreeScreenHeight + margin, width: screenWidth - 2*margin, height: halfFreeScreenHeight - 2*margin))
        self.view.addSubview(outcomingMsgContiner)
        
        //user image view
        userImageView = UIImageView.init(frame: CGRect(x: outcomingMsgContiner.frame.size.width - squareElementSide, y: 0, width: squareElementSide, height: squareElementSide))
        userImageView.image = Account.get(accountId!)?.getChatImage()
        userImageView.layer.cornerRadius = 4.0
        userImageView.clipsToBounds = true
        outcomingMsgContiner.addSubview(userImageView)
        
        //send media button
        sendMediaButton = UIButton.init(frame: CGRect(x: outcomingMsgContiner.frame.size.width - squareElementSide, y: squareElementSide + smallMargin, width: squareElementSide, height: squareElementSide))
        sendMediaButton.setBackgroundImage(UIImage(named: "SEND-MEDIA-GRAY"), for: UIControlState())
        sendMediaButton.addTarget(self, action: #selector(ChatViewController.sendMediaButtonPressed(_:)), for: UIControlEvents.touchUpInside)
        outcomingMsgContiner.addSubview(sendMediaButton)
        
        //outcoming msg view
        outcomingMsgView = UITextView.init(frame: CGRect(x: 0, y: 0, width: outcomingMsgContiner.frame.size.width - squareElementSide - smallMargin, height: halfFreeScreenHeight - 2*margin))
        outcomingMsgView.backgroundColor = UIColor.TurntWhite()
        outcomingMsgView.font = UIFont.systemFont(ofSize: 15.0)
        outcomingMsgView.textColor = UIColor.TurntChatTextColor()
        outcomingMsgView.isUserInteractionEnabled = false
        outcomingMsgView.layer.cornerRadius = 4.0
        outcomingMsgView.clipsToBounds = true
        outcomingMsgContiner.addSubview(outcomingMsgView)
        
    //incoming container
        incomingMsgContainer = UIView.init(frame: CGRect(x: margin, y: margin, width: screenWidth - 2*margin, height: halfFreeScreenHeight - 2*margin))
        self.view.addSubview(incomingMsgContainer)
        
        //friend image view
        friendImageView = UIImageView.init(frame: CGRect(x: 0, y: 0, width: squareElementSide, height: squareElementSide))
        friendImageView.image = Friend.get(friendId!)?.getImage()
        friendImageView.layer.cornerRadius = 4.0
        friendImageView.clipsToBounds = true
        incomingMsgContainer.addSubview(friendImageView)
        
        //incoming media button
        incomingMediaButton = UIButton.init(frame: CGRect(x: 0, y: squareElementSide + smallMargin, width: squareElementSide, height: squareElementSide))
        incomingMediaButton.setBackgroundImage(UIImage(named: "NEW-PHOTO-GRAY"), for: UIControlState())
        incomingMediaButton.addTarget(self, action: #selector(ChatViewController.incomingMediaButtonPressed(_:)), for: UIControlEvents.touchUpInside)
//        incomingMediaButton.userInteractionEnabled = false
        incomingMsgContainer.addSubview(incomingMediaButton)
        
        //incomin msg view
        incomingMsgView = UITextView.init(frame: CGRect(x: squareElementSide + smallMargin, y: 0, width: incomingMsgContainer.frame.size.width - squareElementSide - smallMargin, height: halfFreeScreenHeight - 2*margin))
        incomingMsgView.backgroundColor = UIColor.TurntWhite()
        incomingMsgView.isUserInteractionEnabled = false
        incomingMsgView.layer.cornerRadius = 4.0
        incomingMsgView.clipsToBounds = true
        incomingMsgContainer.addSubview(incomingMsgView)
        
//separating line
        let separatorView = UIImageView.init(frame: CGRect(x: margin, y: halfFreeScreenHeight, width: screenWidth - 2*margin, height: 1))
        separatorView.image = UIImage(named: "SEPARATOR")
        self.view.addSubview(separatorView)
    }
    
    func adjustViewToHideMediaMsg() {
        self.navigationController!.navigationBar.isHidden = false
        self.view.frame.origin.y += 64
        self.view.frame.size.height -= 64.0
        enterMsgTextView.becomeFirstResponder()
    }
    
    func adjustViewToShowMediaMsg() {
        self.navigationController!.navigationBar.isHidden = true
        self.view.frame.origin.y -= 64
        self.view.frame.size.height += 64.0
        enterMsgTextView.resignFirstResponder()
    }
    
    //MARK: media message display
    func showVideoMsg() {
        displayingMediaMode = true
        self.adjustViewToShowMediaMsg()
//        let tap = UITapGestureRecognizer.init(target: self, action: Selector("msgViewTapped:"))
//        tap.delegate = self
        let player = AVPlayer(url: self.videoUrl)
        playerController.player = player
        playerController.showsPlaybackControls = false
        self.addChildViewController(playerController)
//        playerController.view.addGestureRecognizer(tap)
        playerController.view.isUserInteractionEnabled = true
        self.view.addSubview(playerController.view)
        playerController.view.frame = self.view.frame
        player.play()
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.hideVideoMsg(_:)),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    func hideVideoMsg(_ note: Notification) {
        displayingMediaMode = false
        if (self.view.subviews.contains(playerController.view)) {
            playerController.view.removeFromSuperview()
            self.adjustViewToHideMediaMsg()
            incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO-GRAY"), for: UIControlState())
            incomingMediaButton.isEnabled = false
        }
    }
    
    func showPhotoMsg() {
        displayingMediaMode = true
        self.adjustViewToShowMediaMsg()
        let tap = UITapGestureRecognizer.init(target: self, action:#selector(ChatViewController.tapPhotoMsg(_:)))
        tap.delegate = self
        photoMsgView = UIImageView(frame: self.view.frame)
        photoMsgView.image = photo
        photoMsgView.isUserInteractionEnabled = true
        photoMsgView.addGestureRecognizer(tap)
        self.view.addSubview(photoMsgView)
    }
    
    func hidePhotoMsg() {
        print("hidePhotoMsg")
        displayingMediaMode = false
        if (self.view.subviews.contains(photoMsgView)) {
            photoMsgView.removeFromSuperview()
            self.adjustViewToHideMediaMsg()
            incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO-GRAY"), for: UIControlState())
            incomingMediaButton.isEnabled = false
        }
    }
    
    func tapPhotoMsg(_ recognizer: UITapGestureRecognizer) {
        self.hidePhotoMsg();
    }
}
