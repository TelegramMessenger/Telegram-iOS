import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SafariServices
import TelegramPresentationData
import AccountContext
import ShareController
import OpenInExternalAppUI
import TelegramUIPreferences

class InstantPageReferenceControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let sourcePeerType: MediaAutoDownloadPeerType
    private let theme: InstantPageTheme
    private var presentationData: PresentationData
    private let webPage: TelegramMediaWebpage
    private let anchorText: NSAttributedString

    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let contentBackgroundNode: ASImageNode
    private var contentNode: InstantPageContentNode?
    private let titleNode: ASTextNode
    private let separatorNode: ASDisplayNode
    private let closeButton: HighlightableButtonNode
    private var linkHighlightingNode: LinkHighlightingNode?
    private var textSelectionNode: LinkHighlightingNode?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var openUrl: (InstantPageUrlItem) -> Void
    private var openUrlIn: (InstantPageUrlItem) -> Void
    private var present: (ViewController, Any?) -> Void
    
    var dismiss: (() -> Void)?
    var close: (() -> Void)?
    
    init(context: AccountContext, sourcePeerType: MediaAutoDownloadPeerType, theme: InstantPageTheme, webPage: TelegramMediaWebpage, anchorText: NSAttributedString, openUrl: @escaping (InstantPageUrlItem) -> Void, openUrlIn: @escaping (InstantPageUrlItem) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.sourcePeerType = sourcePeerType
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.theme = theme
        self.webPage = webPage
        self.anchorText = anchorText
        self.openUrl = openUrl
        self.openUrlIn = openUrlIn
        self.present = present
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        let roundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: self.theme.overlayPanelColor)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false
        self.contentContainerNode.clipsToBounds = true
        
        self.contentBackgroundNode = ASImageNode()
        self.contentBackgroundNode.displaysAsynchronously = false
        self.contentBackgroundNode.displayWithoutProcessing = true
        self.contentBackgroundNode.image = roundedBackground
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.InstantPage_Reference, font: Font.bold(17.0), textColor: self.theme.panelSecondaryColor)
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = self.theme.controlColor
        
        self.closeButton = HighlightableButtonNode()
            
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
        
        self.wrappingScrollNode.addSubnode(self.contentBackgroundNode)
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        
        self.contentContainerNode.addSubnode(self.titleNode)
        self.contentContainerNode.addSubnode(self.separatorNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        recognizer.delaysTouchesBegan = false
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self, let contentNode = strongSelf.contentNode {
                return strongSelf.tapActionAtPoint(point.offsetBy(dx: -contentNode.frame.minX, dy: -contentNode.frame.minY))
            }
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self, let contentNode = strongSelf.contentNode {
                strongSelf.updateTouchesAtPoint(point?.offsetBy(dx: -contentNode.frame.minX, dy: -contentNode.frame.minY))
            }
        }
        self.contentContainerNode.view.addGestureRecognizer(recognizer)
    }
    
    @objc func closeButtonPressed() {
        self.close?()
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.closeButtonPressed()
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), to: dimPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.layer.animateBoundsOriginYAdditive(from: -offset, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        var dimCompleted = false
        var offsetCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && offsetCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            offsetCompleted = true
            internalCompletion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) {
                return self.dimNode.view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.closeButtonPressed()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleAreaHeight: CGFloat = 54.0
        var contentHeight = titleAreaHeight + bottomInset
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
        
        if self.contentNode == nil || self.contentNode?.frame.width != width {
            self.contentNode?.removeFromSupernode()
            
            var media: [MediaId: Media] = [:]
            if case let .Loaded(content) = self.webPage.content, let instantPage = content.instantPage  {
                media = instantPage.media
            }
            
            let sideInset: CGFloat = 16.0
            let (_, items, contentSize) = layoutTextItemWithString(self.anchorText, boundingWidth: width - sideInset * 2.0, offset: CGPoint(x: sideInset, y: sideInset), media: media, webpage: self.webPage)
            let contentNode = InstantPageContentNode(context: self.context, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder, sourcePeerType: self.sourcePeerType, theme: self.theme, items: items, contentSize: CGSize(width: width, height: contentSize.height), inOverlayPanel: true, openMedia: { _ in }, longPressMedia: { _ in }, openPeer: { _ in }, openUrl: { _ in })
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: titleAreaHeight), size: CGSize(width: width, height: contentSize.height)))
            self.contentContainerNode.insertSubnode(contentNode, at: 0)
            self.contentNode = contentNode
            
            contentHeight += contentSize.height + sideInset
            
            contentNode.updateVisibleItems(visibleBounds: contentNode.bounds, animated: false)
        }
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
        let contentFrame = contentContainerFrame
        
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.size.width, height: contentFrame.size.height + 2000.0))
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateFrame(node: self.contentBackgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: width, height: titleAreaHeight))
        let titleFrame = CGRect(origin: CGPoint(x: 17.0, y: 17.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        //transition.updateFrame(node: self.closeButtonNode, frame: CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: width, height: buttonHeight)))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: titleAreaHeight), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))
    }
    
    func tapActionAtPoint(_ point: CGPoint) -> TapLongTapOrDoubleTapGestureRecognizerAction {
        if let contentNode = self.contentNode {
            for item in contentNode.currentLayout.items {
                let frame = contentNode.effectiveFrameForItem(item)
                if frame.contains(point) {
                    if item is InstantPagePeerReferenceItem {
                        return .fail
                    } else if item is InstantPageAudioItem {
                        return .fail
                    } else if item is InstantPageArticleItem {
                        return .fail
                    } else if item is InstantPageFeedbackItem {
                        return .fail
                    }
                    if !(item is InstantPageImageItem || item is InstantPagePlayableVideoItem) {
                        break
                    }
                }
            }
        }
        return .waitForSingleTap
    }
    
    private func updateTouchesAtPoint(_ location: CGPoint?) {
        var rects: [CGRect]?
        if let contentNode = self.contentNode, let location = location {
            for item in contentNode.currentLayout.items {
                let itemFrame = contentNode.effectiveFrameForItem(item)
                if itemFrame.contains(location) {
                    var contentOffset = CGPoint()
                    if let item = item as? InstantPageScrollableItem {
                        contentOffset = contentNode.scrollableContentOffset(item: item)
                    }
                    var itemRects = item.linkSelectionRects(at: location.offsetBy(dx: -itemFrame.minX + contentOffset.x, dy: -itemFrame.minY))
                    for i in 0 ..< itemRects.count {
                        itemRects[i] = itemRects[i].offsetBy(dx: itemFrame.minX - contentOffset.x + contentNode.frame.minX, dy: itemFrame.minY + contentNode.frame.minY).insetBy(dx: -2.0, dy: -2.0)
                    }
                    if !itemRects.isEmpty {
                        rects = itemRects
                        break
                    }
                }
            }
        }
        
        if let rects = rects {
            let linkHighlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                linkHighlightingNode = current
            } else {
                linkHighlightingNode = LinkHighlightingNode(color: self.theme.linkHighlightColor)
                linkHighlightingNode.isUserInteractionEnabled = false
                self.linkHighlightingNode = linkHighlightingNode
                self.contentContainerNode.addSubnode(linkHighlightingNode)
            }
            linkHighlightingNode.frame = CGRect(origin: CGPoint(), size: self.contentContainerNode.bounds.size)
            linkHighlightingNode.updateRects(rects)
        } else if let linkHighlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                linkHighlightingNode?.removeFromSupernode()
            })
        }
    }
    
    private func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        if let contentNode = self.contentNode {
            for item in contentNode.currentLayout.items {
                let itemFrame = contentNode.effectiveFrameForItem(item)
                if itemFrame.contains(location) {
                    if let item = item as? InstantPageTextItem, item.selectable {
                        return (item, CGPoint(x: itemFrame.minX - item.frame.minX + contentNode.frame.minX, y: itemFrame.minY - item.frame.minY + contentNode.frame.minY))
                    } else if let item = item as? InstantPageScrollableItem {
                        let contentOffset = contentNode.scrollableContentOffset(item: item)
                        if let (textItem, parentOffset) = item.textItemAtLocation(location.offsetBy(dx: -itemFrame.minX + contentOffset.x, dy: -itemFrame.minY)) {
                            return (textItem, itemFrame.origin.offsetBy(dx: parentOffset.x - contentOffset.x + contentNode.frame.minX, dy: parentOffset.y + contentNode.frame.minY))
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func urlForTapLocation(_ location: CGPoint) -> InstantPageUrlItem? {
        if let contentNode = self.contentNode, let (item, parentOffset) = self.textItemAtLocation(location) {
            return item.urlAttribute(at: location.offsetBy(dx: -item.frame.minX - parentOffset.x + contentNode.frame.minX, dy: -item.frame.minY - parentOffset.y + contentNode.frame.minY))
        }
        return nil
    }
    
    @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        guard let contentNode = self.contentNode else {
            return
        }
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    let location = location.offsetBy(dx: -contentNode.frame.minX, dy: -contentNode.frame.minY)
                    switch gesture {
                        case .tap:
                            if let url = self.urlForTapLocation(location) {
                                self.close?()
                                self.openUrl(url)
                            }
                        case .longTap:
                            if let url = self.urlForTapLocation(location) {
                                let canOpenIn = availableOpenInOptions(context: self.context, item: .url(url: url.url)).count > 1
                                let openText = canOpenIn ? self.presentationData.strings.Conversation_FileOpenIn : self.presentationData.strings.Conversation_LinkDialogOpen
                                let actionSheet = ActionSheetController(instantPageTheme: self.theme)
                                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                                    ActionSheetTextItem(title: url.url),
                                    ActionSheetButtonItem(title: openText, color: .accent, action: { [weak self, weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        if let strongSelf = self {
                                            strongSelf.close?()
                                            if canOpenIn {
                                                strongSelf.openUrlIn(url)
                                            } else {
                                                strongSelf.openUrl(url)
                                            }
                                        }
                                    }),
                                    ActionSheetButtonItem(title: self.presentationData.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        UIPasteboard.general.string = url.url
                                    }),
                                    ActionSheetButtonItem(title: self.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        if let link = URL(string: url.url) {
                                            let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                                        }
                                    })
                                    ]), ActionSheetItemGroup(items: [
                                        ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                            actionSheet?.dismissAnimated()
                                        })
                                    ])])
                                self.present(actionSheet, nil)
                            } else if let (item, parentOffset) = self.textItemAtLocation(location) {
                                let textFrame = item.frame
                                var itemRects = item.lineRects()
                                for i in 0 ..< itemRects.count {
                                    itemRects[i] = itemRects[i].offsetBy(dx: parentOffset.x + textFrame.minX, dy: parentOffset.y + textFrame.minY).insetBy(dx: -2.0, dy: -2.0)
                                }
                                self.updateTextSelectionRects(itemRects, text: item.plainText())
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
    
    private func updateTextSelectionRects(_ rects: [CGRect], text: String?) {
        if let text = text, !rects.isEmpty {
            let textSelectionNode: LinkHighlightingNode
            if let current = self.textSelectionNode {
                textSelectionNode = current
            } else {
                textSelectionNode = LinkHighlightingNode(color: UIColor.lightGray.withAlphaComponent(0.4))
                textSelectionNode.isUserInteractionEnabled = false
                self.textSelectionNode = textSelectionNode
                self.contentContainerNode.addSubnode(textSelectionNode)
            }
            textSelectionNode.frame = CGRect(origin: CGPoint(), size: self.contentContainerNode.bounds.size)
            textSelectionNode.updateRects(rects)
            
            var coveringRect = rects[0]
            for i in 1 ..< rects.count {
                coveringRect = coveringRect.union(rects[i])
            }
            
            let controller = ContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: {
                UIPasteboard.general.string = text
            }), ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuShare, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuShare), action: { [weak self] in
                if let strongSelf = self, case let .Loaded(content) = strongSelf.webPage.content {
                    strongSelf.present(ShareController(context: strongSelf.context, subject: .quote(text: text, url: content.url)), nil)
                }
            })])
            controller.dismissed = { [weak self] in
                self?.updateTextSelectionRects([], text: nil)
            }
            self.present(controller, ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                if let strongSelf = self {
                    return (strongSelf.contentContainerNode, coveringRect.insetBy(dx: -3.0, dy: -3.0), strongSelf, strongSelf.bounds)
                } else {
                    return nil
                }
            }))
            textSelectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
        } else if let textSelectionNode = self.textSelectionNode {
            self.textSelectionNode = nil
            textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                textSelectionNode?.removeFromSupernode()
            })
        }
    }
}
