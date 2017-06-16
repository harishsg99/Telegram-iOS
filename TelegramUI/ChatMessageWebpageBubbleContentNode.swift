import Foundation
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

final class ChatMessageWebpageBubbleContentNode: ChatMessageBubbleContentNode {
    private var item: ChatMessageItem?
    private var webPage: TelegramMediaWebpage?
    
    private let contentNode: ChatMessageAttachedContentNode
    
    override var properties: ChatMessageBubbleContentProperties {
        return ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0)
    }
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.contentNode.visibility = self.visibility
        }
    }
    
    required init() {
        self.contentNode = ChatMessageAttachedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let contentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, position, constrainedSize in
            var webPage: TelegramMediaWebpage?
            var webPageContent: TelegramMediaWebpageLoadedContent?
            for media in item.message.media {
                if let media = media as? TelegramMediaWebpage {
                    webPage = media
                    if case let .Loaded(content) = media.content {
                        webPageContent = content
                    }
                    break
                }
            }
            
            var title: String?
            var subtitle: String?
            var text: String?
            var mediaAndFlags: (Media, ChatMessageAttachedContentNodeMediaFlags)?
            
            if let webpage = webPageContent {
                if let websiteName = webpage.websiteName, !websiteName.isEmpty {
                    title = websiteName
                }
                
                if let title = webpage.title, !title.isEmpty {
                    subtitle = title
                }
                
                if let textValue = webpage.text, !textValue.isEmpty {
                    text = textValue
                }
                
                if let file = webpage.file {
                    mediaAndFlags = (file, [])
                } else if let image = webpage.image {
                    if let type = webpage.type, ["photo"].contains(type) {
                        var flags = ChatMessageAttachedContentNodeMediaFlags()
                        if webpage.instantPage != nil {
                            flags.insert(.preferMediaBeforeText)
                        }
                        mediaAndFlags = (image, flags)
                    } else if let _ = largestImageRepresentation(image.representations)?.dimensions {
                        mediaAndFlags = (image, [.preferMediaInline])
                    }
                }
            }
            
            let (initialWidth, continueLayout) = contentNodeLayout(item.theme, item.strings, item.account, item.message, item.read, title, subtitle, text, nil, mediaAndFlags, true, layoutConstants, position, constrainedSize)
            
            return (initialWidth, { constrainedSize in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize)
                
                return (refinedWidth, { boundingWidth in
                    let (size, apply) = finalizeLayout(boundingWidth)
                    
                    return (size, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.webPage = webPage
                            
                            apply(animation)
                            
                            strongSelf.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }
    
    override func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        if self.bounds.contains(point) {
            if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
                if content.instantPage != nil {
                    return .instantPage
                }
            }
        }
        return .none
    }
    
    override func updateHiddenMedia(_ media: [Media]?) {
        self.contentNode.updateHiddenMedia(media)
    }
    
    override func transitionNode(media: Media) -> ASDisplayNode? {
        return self.contentNode.transitionNode(media: media)
    }
}
