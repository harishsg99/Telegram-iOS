import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox

final class GameController: ViewController {
    private var controllerNode: GameControllerNode {
        return self.displayNode as! GameControllerNode
    }
    
    private let account: Account
    private let url: String
    private let message: Message
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false
    
    init(account: Account, url: String, message: Message) {
        self.account = account
        self.url = url
        self.message = message
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarTheme: NavigationBarTheme(rootControllerTheme: (account.telegramApplicationContext.currentPresentationData.with { $0 }).theme))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Close, style: .plain, target: self, action: #selector(self.closePressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationShareIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.sharePressed))
        
        for media in message.media {
            if let game = media as? TelegramMediaGame {
                let titleView = GameControllerTitleView(theme: self.presentationData.theme)
                
                var botPeer: Peer?
                inner: for attribute in message.attributes {
                    if let attribute = attribute as? InlineBotMessageAttribute {
                        botPeer = message.peers[attribute.peerId]
                        break inner
                    }
                }
                if botPeer == nil {
                    botPeer = message.author
                }
                
                titleView.set(title: game.title, subtitle: "@\(botPeer?.addressName ?? "")")
                self.navigationItem.titleView = titleView
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func closePressed() {
        self.dismiss()
    }
    
    @objc func sharePressed() {
        
    }
    
    override func loadDisplayNode() {
        self.displayNode = GameControllerNode(presentationData: self.presentationData, url: self.url)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            self.controllerNode.animateIn()
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
