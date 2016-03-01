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
    var videoUrl: NSURL!
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
        
        socket = WebSocket(url: NSURL(scheme: "http", host:ConfigManager.sharedInstance.WebSocketUrl!, path: "/chat/\(channelId!)/\(accountId!)")!)
        socket!.delegate = self
        socket!.connect()
        
        progressView.hidden = true
        progressView.setProgress(0, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(animated: Bool) {
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
    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
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
    
    func textViewDidChangeSelection(textView: UITextView) {
        let maxHeight: CGFloat = 180.0
        let lineHeight = textView.font!.lineHeight
        let contentHeight = textView.contentSize.height
        let newViewHeight = contentHeight + lineHeight
        if newViewHeight > maxHeight {
           
        }
    }
    
    //MARK: websocket delegate methods
    func websocketDidConnect(socket: WebSocket) {
        print("Chat connected \(socket)")
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        print("Chat disconnected \(error?.localizedDescription)")
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: NSData) {
        print("Chat data transfer")
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        if let dataFromString = text.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
            let json = JSON(data: dataFromString)
            print("\(json["type"]) received")
            
            if json["type"].stringValue == "status" {
                print("Update user status: \(json)")
                if json["online"].stringValue == "true" {
                    statusView.hidden = false
                    sendButton.setImage(UIImage(named: "SEND"), forState: UIControlState.Normal)
                    sendButton.tag = 1
                    sendMediaButton.setImage(UIImage(named: "SEND-MEDIA"), forState: UIControlState.Normal)
                    sendMediaButton.enabled = true
                } else {
                    statusView.hidden = true
                    sendButton.setImage(UIImage(named: "POKE-BUTTON"), forState: UIControlState.Normal)
                    sendButton.tag = 0
                    sendMediaButton.setImage(UIImage(named: "SEND-MEDIA-GRAY"), forState: UIControlState.Normal)
                    sendMediaButton.enabled = false
                    incomingMediaButton.enabled = false
                }
            } else if json["type"].stringValue == "text" {
                incomingMsgView.text = json["content"].stringValue
                incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO-GRAY"), forState: UIControlState.Normal)
                incomingMediaButton.enabled = false
                }
              else if json["type"].stringValue == "image" {
                if let image: String = json["content"].string {
                    let imgData: NSData = NSData(base64EncodedString: image, options:NSDataBase64DecodingOptions(rawValue: 0))!
                    self.photo = UIImage(data: imgData)!
                }
                incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO"), forState: UIControlState.Normal)
                incomingMediaButton.tag = 0
                incomingMediaButton.enabled = true
            }
            else if json["type"].stringValue == "video" {
                if let video: String = json["content"].string {
                    let videoData: NSData = NSData(base64EncodedString: video, options:NSDataBase64DecodingOptions(rawValue: 0))!
                    let writePath: NSURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("receivedMovie.mov")
                    videoData.writeToURL(writePath, atomically: true)
                    self.videoUrl = writePath
                }
                incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO"), forState: UIControlState.Normal)
                incomingMediaButton.tag = 1
                incomingMediaButton.enabled = true
            }
        }
    }
    
    //MARK: buttons actions
    func cleanButtonPressed(sender: UIButton) {
        print("cleanButtonPressed")
        outcomingMsgView.text! = ""
        incomingMsgView.text! = ""
        enterMsgTextView.text! = ""
    }
    
    func sendButtonPressed(sender: UIButton) {
        print("send/poke ButtonPressed")
        if sender.tag == 1 {
            let dict = [ "content": "\(enterMsgTextView.text!)", "type" : "text"  ]
            let data = try? NSJSONSerialization.dataWithJSONObject(dict, options: [])
            let string = NSString(data: data!, encoding: NSUTF8StringEncoding)
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
    
    func incomingMediaButtonPressed(sender: UIButton) {
        displayingMediaMode = true
        print("incomingMediaButtonPressed")
        if sender.tag == 0 {
            self.showPhotoMsg()
            let dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(4 * Double(NSEC_PER_SEC)))
            dispatch_after(dispatchTime, dispatch_get_main_queue(), {
                self.hidePhotoMsg()
            })
        } else if sender.tag == 1 {
            self.showVideoMsg()
        }
    }
    
    func sendMediaButtonPressed(sender: UIButton) {
        displayingMediaMode = true
        print("sendMediaButtonPressed")
        presentActionSheet()
    }

    func presentActionSheet() {
        let actionSheet: UIAlertController = UIAlertController(title:nil, message:nil, preferredStyle:UIAlertControllerStyle.ActionSheet)
        actionSheet.addAction(UIAlertAction(title:"Choose photo from library".localized, style:UIAlertActionStyle.Default, handler:{ action in
            self.choosePhotoFromLibrery()
        }))
        actionSheet.addAction(UIAlertAction(title:"Take photo".localized, style:UIAlertActionStyle.Default, handler:{ action in
            self.takePhoto()
        }))
        actionSheet.addAction(UIAlertAction(title:"Cancel".localized, style:UIAlertActionStyle.Cancel, handler:nil))
        presentViewController(actionSheet, animated:true, completion:nil)
    }
    
    func choosePhotoFromLibrery() {
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

    func takePhoto() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
            imagePicker.delegate = self
            imagePicker.sourceType = .Camera
            let availableMediaTypes = UIImagePickerController.availableMediaTypesForSourceType(.Camera)
            imagePicker.mediaTypes = availableMediaTypes!
            imagePicker.videoMaximumDuration = 10.0
            self.presentViewController(imagePicker, animated: true, completion: nil)
        } else {
            print("camera not avaliable")
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let mediaType = info["UIImagePickerControllerMediaType"]!
        var dict: [String: String] = [:]
        
        if (mediaType.isEqual("public.movie")) {
            //writing video to socket as string
            let videoUrl = info["UIImagePickerControllerMediaURL"] as! NSURL
            let video: NSData = NSData(contentsOfURL: videoUrl)!
            let videoAsString: String = video.base64EncodedStringWithOptions([])
            dict = ["content": "\(videoAsString)", "type" : "video"]
        }
        else if (mediaType.isEqual("public.image")) {
            //writing image to socket as string
            let image: UIImage = info["UIImagePickerControllerOriginalImage"] as! UIImage
            let imageAsString: String = UIImageJPEGRepresentation(image, 0.1)!.base64EncodedStringWithOptions([])
            dict = ["content": "\(imageAsString)", "type" : "image"]
        }
        
        let data = try? NSJSONSerialization.dataWithJSONObject(dict, options: [])
        let string = NSString(data: data!, encoding: NSUTF8StringEncoding)
        self.socket!.writeString(string as! String)
        
        //progress bar of sending (now fake)
        self.progressView.hidden = false
        self.counter = 0
        for _ in 0..<100 {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
                sleep(2)
                dispatch_async(dispatch_get_main_queue(), {
                    if self.counter == 99 {
                        self.progressView.hidden = true
                    } else {
                        self.counter++
                    }
                    return
                })
            })
        }
        
        self.sendMediaButton.enabled = true
        self.dismissViewControllerAnimated(true, completion: nil)
        self.enterMsgTextView.becomeFirstResponder()
        displayingMediaMode = false
    }
    
    //MARK: view configuration
    func configureNavigationBarView() {
        let friend = Friend.get(friendId!)
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.Plain, target: nil, action: nil)
        let cleanButton = UIBarButtonItem(title: "Clear".localized, style: UIBarButtonItemStyle.Plain, target: self, action:"cleanButtonPressed:")
        cleanButton.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFontOfSize(15)], forState: UIControlState.Normal)
        self.navigationItem.rightBarButtonItem = cleanButton
        
        let friendUsername: NSString = "\(friend!.username)"
        let friendUsernameSize = friendUsername.sizeWithAttributes([NSFontAttributeName: UIFont.boldSystemFontOfSize(18)])
        
        let navBarTitleView = UIView.init(frame: CGRectMake(0, 0, friendUsernameSize.width + 15, friendUsernameSize.height))
        
        let usernameLabel = UILabel.init(frame: CGRectMake(10, 0, friendUsernameSize.width, friendUsernameSize.height))
        usernameLabel.text = "\(friend!.username)"
        usernameLabel.textColor = UIColor.TurntWhite()
        usernameLabel.font = UIFont.boldSystemFontOfSize(18)
        
        statusView = UIImageView.init(frame: CGRectMake(0, friendUsernameSize.height/2 - 4, 8, 8))
        statusView.backgroundColor = UIColor.TurntGreenLumo()
        statusView.layer.cornerRadius = 4
        statusView.clipsToBounds = true
        
        navBarTitleView.addSubview(usernameLabel)
        navBarTitleView.addSubview(statusView)

        self.navigationItem.titleView = navBarTitleView
    }
    
    func configureView() {
        let screenWidth = UIScreen.mainScreen().bounds.width
        let screenHeight = UIScreen.mainScreen().bounds.height
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
        progressView = UIProgressView.init(frame: CGRectMake(0, 0, screenWidth, 10))
        progressView.progressTintColor = UIColor.TurntGreenLumo()
        progressView.backgroundColor = UIColor.clearColor()
        self.view.addSubview(progressView)
        
//input Container
        inputContainerView = UIView.init(frame: CGRectMake(0, inputContainerViewY, screenWidth, inputContainerViewHeight))
        inputContainerView.backgroundColor = UIColor.TurntWhite()
        self.view.addSubview(inputContainerView)
        
    //enterMsg
        enterMsgTextView = UITextField.init(frame: CGRectMake(margin, enterMsgTextViewHeight/2, screenWidth - pokeButtonWidth - 3*margin, enterMsgTextViewHeight))
        enterMsgTextView.backgroundColor = UIColor.TurntWhite()
        enterMsgTextView.font = UIFont.systemFontOfSize(15)
        enterMsgTextView.placeholder = "Enter message"
        enterMsgTextView.becomeFirstResponder()
        inputContainerView.addSubview(enterMsgTextView)
        
    //pokeButton
        sendButton = UIButton.init(frame: CGRectMake(enterMsgTextView.frame.size.width + 2*margin, (inputContainerViewHeight - pokeButtonHeight)/2, pokeButtonWidth, pokeButtonHeight))
        sendButton.setBackgroundImage(UIImage(named: "POKE-BUTTON"), forState: UIControlState.Normal)
        sendButton.addTarget(self, action: "sendButtonPressed:", forControlEvents: UIControlEvents.TouchUpInside)
        inputContainerView.addSubview(sendButton)
        
//msg Containers
    //outcoming container
        outcomingMsgContiner = UIView.init(frame: CGRectMake(margin, halfFreeScreenHeight + margin, screenWidth - 2*margin, halfFreeScreenHeight - 2*margin))
        self.view.addSubview(outcomingMsgContiner)
        
        //user image view
        userImageView = UIImageView.init(frame: CGRectMake(outcomingMsgContiner.frame.size.width - squareElementSide, 0, squareElementSide, squareElementSide))
        userImageView.image = Account.get(accountId!)?.getChatImage()
        userImageView.layer.cornerRadius = 4.0
        userImageView.clipsToBounds = true
        outcomingMsgContiner.addSubview(userImageView)
        
        //send media button
        sendMediaButton = UIButton.init(frame: CGRectMake(outcomingMsgContiner.frame.size.width - squareElementSide, squareElementSide + smallMargin, squareElementSide, squareElementSide))
        sendMediaButton.setBackgroundImage(UIImage(named: "SEND-MEDIA-GRAY"), forState: UIControlState.Normal)
        sendMediaButton.addTarget(self, action: "sendMediaButtonPressed:", forControlEvents: UIControlEvents.TouchUpInside)
        outcomingMsgContiner.addSubview(sendMediaButton)
        
        //outcoming msg view
        outcomingMsgView = UITextView.init(frame: CGRectMake(0, 0, outcomingMsgContiner.frame.size.width - squareElementSide - smallMargin, halfFreeScreenHeight - 2*margin))
        outcomingMsgView.backgroundColor = UIColor.TurntWhite()
        outcomingMsgView.font = UIFont.systemFontOfSize(15.0)
        outcomingMsgView.textColor = UIColor.TurntChatTextColor()
        outcomingMsgView.userInteractionEnabled = false
        outcomingMsgView.layer.cornerRadius = 4.0
        outcomingMsgView.clipsToBounds = true
        outcomingMsgContiner.addSubview(outcomingMsgView)
        
    //incoming container
        incomingMsgContainer = UIView.init(frame: CGRectMake(margin, margin, screenWidth - 2*margin, halfFreeScreenHeight - 2*margin))
        self.view.addSubview(incomingMsgContainer)
        
        //friend image view
        friendImageView = UIImageView.init(frame: CGRectMake(0, 0, squareElementSide, squareElementSide))
        friendImageView.image = Friend.get(friendId!)?.getImage()
        friendImageView.layer.cornerRadius = 4.0
        friendImageView.clipsToBounds = true
        incomingMsgContainer.addSubview(friendImageView)
        
        //incoming media button
        incomingMediaButton = UIButton.init(frame: CGRectMake(0, squareElementSide + smallMargin, squareElementSide, squareElementSide))
        incomingMediaButton.setBackgroundImage(UIImage(named: "NEW-PHOTO-GRAY"), forState: UIControlState.Normal)
        incomingMediaButton.addTarget(self, action: "incomingMediaButtonPressed:", forControlEvents: UIControlEvents.TouchUpInside)
//        incomingMediaButton.userInteractionEnabled = false
        incomingMsgContainer.addSubview(incomingMediaButton)
        
        //incomin msg view
        incomingMsgView = UITextView.init(frame: CGRectMake(squareElementSide + smallMargin, 0, incomingMsgContainer.frame.size.width - squareElementSide - smallMargin, halfFreeScreenHeight - 2*margin))
        incomingMsgView.backgroundColor = UIColor.TurntWhite()
        incomingMsgView.userInteractionEnabled = false
        incomingMsgView.layer.cornerRadius = 4.0
        incomingMsgView.clipsToBounds = true
        incomingMsgContainer.addSubview(incomingMsgView)
        
//separating line
        let separatorView = UIImageView.init(frame: CGRectMake(margin, halfFreeScreenHeight, screenWidth - 2*margin, 1))
        separatorView.image = UIImage(named: "SEPARATOR")
        self.view.addSubview(separatorView)
    }
    
    func adjustViewToHideMediaMsg() {
        self.navigationController!.navigationBar.hidden = false
        self.view.frame.origin.y += 64
        self.view.frame.size.height -= 64.0
        enterMsgTextView.becomeFirstResponder()
    }
    
    func adjustViewToShowMediaMsg() {
        self.navigationController!.navigationBar.hidden = true
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
        let player = AVPlayer(URL: self.videoUrl)
        playerController.player = player
        playerController.showsPlaybackControls = false
        self.addChildViewController(playerController)
//        playerController.view.addGestureRecognizer(tap)
        playerController.view.userInteractionEnabled = true
        self.view.addSubview(playerController.view)
        playerController.view.frame = self.view.frame
        player.play()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("hideVideoMsg:"),
            name: AVPlayerItemDidPlayToEndTimeNotification, object: player.currentItem)
    }
    
    func hideVideoMsg(note: NSNotification) {
        displayingMediaMode = false
        if (self.view.subviews.contains(playerController.view)) {
            playerController.view.removeFromSuperview()
            self.adjustViewToHideMediaMsg()
            incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO-GRAY"), forState: UIControlState.Normal)
            incomingMediaButton.enabled = false
        }
    }
    
    func showPhotoMsg() {
        displayingMediaMode = true
        self.adjustViewToShowMediaMsg()
        let tap = UITapGestureRecognizer.init(target: self, action:"tapPhotoMsg:")
        tap.delegate = self
        photoMsgView = UIImageView(frame: self.view.frame)
        photoMsgView.image = photo
        photoMsgView.userInteractionEnabled = true
        photoMsgView.addGestureRecognizer(tap)
        self.view.addSubview(photoMsgView)
    }
    
    func hidePhotoMsg() {
        print("hidePhotoMsg")
        displayingMediaMode = false
        if (self.view.subviews.contains(photoMsgView)) {
            photoMsgView.removeFromSuperview()
            self.adjustViewToHideMediaMsg()
            incomingMediaButton.setImage(UIImage(named: "NEW-PHOTO-GRAY"), forState: UIControlState.Normal)
            incomingMediaButton.enabled = false
        }
    }
    
    func tapPhotoMsg(recognizer: UITapGestureRecognizer) {
        self.hidePhotoMsg();
    }
}
