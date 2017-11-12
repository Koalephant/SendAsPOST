//
//  ShareViewController.swift
//  Send As Post Share Extension
//
//  Created by Andy Brett on 11/11/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import Social
import Alamofire
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {

    override func viewDidLoad() {
        self.placeholder = "Caption"
    }
    
    override func isContentValid() -> Bool {
        let defaults = UserDefaults(suiteName: "group.sendaspost.sendaspost")
        return defaults?.string(forKey: "defaultUrl") != nil
    }
    
    func uploadImage(imageData : Data, encodingCompletion : (() -> Void)?) {
        let defaults = UserDefaults(suiteName: "group.sendaspost.sendaspost")
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(self.contentText.data(using: .utf8)!, withName: "caption")
                multipartFormData.append(imageData, withName: "image")
                if let params = defaults?.dictionary(forKey: "additionalParams") as? [String : String] {
                    for key in params.keys {
                        if let valueData = params[key]?.data(using: .utf8) {
                            multipartFormData.append(valueData, withName: key)
                        }
                    }
                }
        },
            to: (defaults?.string(forKey: "defaultUrl"))!,
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON { response in
                        debugPrint(response)
                    }
                case .failure(let encodingError):
                    print(encodingError)
                }
                encodingCompletion?()
        }
        )
    }
    
    override func didSelectPost() {
        guard let items = self.extensionContext?.inputItems as? [NSExtensionItem] else { return }

        for item in items {
            guard let attachments = item.attachments as? [NSItemProvider] else { continue }
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    if #available(iOSApplicationExtension 11.0, *) {
                        attachment.loadFileRepresentation(forTypeIdentifier: kUTTypeImage as String, completionHandler: { (url, error) in
                            if url == nil || error != nil { return }
                            guard let imageData = NSData.init(contentsOf: url!) as Data? else { return }
                            self.uploadImage(imageData: imageData, encodingCompletion: {
                                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                            })
                        })
                    } else {
                        attachment.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil, completionHandler: { (decoder, error) in
                            if error != nil { return }
                            
                            if let url = decoder as? URL {
                                guard let imageData = NSData.init(contentsOf: url) as Data? else { return }
                                self.uploadImage(imageData: imageData, encodingCompletion: {
                                    self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                                })
                            } else if let image = decoder as? UIImage {
                                guard let imageData = UIImageJPEGRepresentation(image, 1) else { return }
                                self.uploadImage(imageData: imageData, encodingCompletion: {
                                    self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                                })
                            }
                        })
                    }
                }
            }
        }
    }
    
    override func configurationItems() -> [Any]! {
        let postUrlItem = SLComposeSheetConfigurationItem.init()
        postUrlItem?.title = "POST to:"
        let defaults = UserDefaults(suiteName: "group.sendaspost.sendaspost")
        postUrlItem?.value = defaults?.string(forKey: "defaultUrl") ?? "Choose URL..."
        postUrlItem?.tapHandler = {
            // it would be preferable to do this by overriding viewDidAppear and calling
            // reloadConfigurationItems, but that method isn't being called when the
            // child viewController is popped off the stack, soo....
            let selectUrlViewController = SelectUrlViewController()
            selectUrlViewController.parentComposeServiceViewController = self
            self.pushConfigurationViewController(selectUrlViewController)
        }
        return [postUrlItem as Any]
    }
}
