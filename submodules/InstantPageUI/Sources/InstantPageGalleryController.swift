import Foundation
import UIKit
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import SafariServices
import TelegramPresentationData
import AccountContext
import GalleryUI
import TelegramUniversalVideoContent
import OpenInExternalAppUI

public struct InstantPageGalleryEntryLocation: Equatable {
    public let position: Int32
    public let totalCount: Int32
    
    public init(position: Int32, totalCount: Int32) {
        self.position = position
        self.totalCount = totalCount
    }
    
    public static func ==(lhs: InstantPageGalleryEntryLocation, rhs: InstantPageGalleryEntryLocation) -> Bool {
        return lhs.position == rhs.position && lhs.totalCount == rhs.totalCount
    }
}

public struct InstantPageGalleryEntry: Equatable {
    public let index: Int32
    public let pageId: MediaId
    public let media: InstantPageMedia
    public let caption: RichText?
    public let credit: RichText?
    public let location: InstantPageGalleryEntryLocation?
    
    public init(index: Int32, pageId: MediaId, media: InstantPageMedia, caption: RichText?, credit: RichText?, location: InstantPageGalleryEntryLocation?) {
        self.index = index
        self.pageId = pageId
        self.media = media
        self.caption = caption
        self.credit = credit
        self.location = location
    }
    
    public static func ==(lhs: InstantPageGalleryEntry, rhs: InstantPageGalleryEntry) -> Bool {
        return lhs.index == rhs.index && lhs.pageId == rhs.pageId && lhs.media == rhs.media && lhs.caption == rhs.caption && lhs.credit == rhs.credit && lhs.location == rhs.location
    }
    
    func item(context: AccountContext, webPage: TelegramMediaWebpage, message: Message?, presentationData: PresentationData, fromPlayingVideo: Bool, landscape: Bool, openUrl: @escaping (InstantPageUrlItem) -> Void, openUrlOptions: @escaping (InstantPageUrlItem) -> Void) -> GalleryItem {
        let caption: NSAttributedString
        let credit: NSAttributedString
        
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(16.0))
        styleStack.push(.textColor(.white))
        styleStack.push(.markerColor(UIColor(rgb: 0x313131)))
        styleStack.push(.linkColor(UIColor(rgb: 0x5ac8fa)))
        styleStack.push(.linkMarkerColor(UIColor(rgb: 0x5ac8fa, alpha: 0.2)))
        styleStack.push(.fontSerif(false))
        
        if let url = self.media.url {
            styleStack.push(.lineSpacingFactor(1.45))
            
            let titleString = RichText.bold(.plain(presentationData.strings.InstantPage_TapToOpenLink + "\n"))
            let urlString = RichText.url(text: .plain(url.url), url: url.url, webpageId: url.webpageId)
            
            let concatText: RichText
            if let mediaCaption = self.media.caption {
                concatText = RichText.concat([titleString, urlString, .plain("\n\n"), mediaCaption])
            } else {
                concatText = RichText.concat([titleString, urlString])
            }
            
            caption = attributedStringForRichText(concatText, styleStack: styleStack)
            credit = NSAttributedString(string: "")
        } else {
            if let mediaCaption = self.media.caption {
                caption = attributedStringForRichText(mediaCaption, styleStack: styleStack)
            } else {
                caption = NSAttributedString(string: "")
            }
            
            if let mediaCredit = self.media.credit {
                let styleStack = InstantPageTextStyleStack()
                styleStack.push(.fontSize(14.0))
                styleStack.push(.textColor(.white))
                styleStack.push(.markerColor(UIColor(rgb: 0x313131)))
                styleStack.push(.linkColor(UIColor(rgb: 0x5ac8fa)))
                styleStack.push(.linkMarkerColor(UIColor(rgb: 0x5ac8fa, alpha: 0.2)))
                styleStack.push(.fontSerif(false))
                credit = attributedStringForRichText(mediaCredit, styleStack: styleStack)
            } else {
                credit = NSAttributedString(string: "")
            }
        }
        
        if let image = self.media.media as? TelegramMediaImage {
            return InstantImageGalleryItem(context: context, presentationData: presentationData, itemId: self.index, imageReference: .webPage(webPage: WebpageReference(webPage), media: image), caption: caption, credit: credit, location: self.location, openUrl: openUrl, openUrlOptions: openUrlOptions)
        } else if let file = self.media.media as? TelegramMediaFile {
            if file.isVideo {
                var indexData: GalleryItemIndexData?
                if let location = self.location {
                    indexData = GalleryItemIndexData(position: location.position, totalCount: location.totalCount)
                }
                
                let nativeId: NativeVideoContentId
                if let message = message, case let .Loaded(content) = webPage.content, content.file?.fileId == file.fileId {
                    nativeId = .message(message.stableId, file.fileId)
                } else {
                    nativeId = .instantPage(self.pageId, file.fileId)
                }
                
                return UniversalVideoGalleryItem(context: context, presentationData: presentationData, content: NativeVideoContent(id: nativeId, fileReference: .webPage(webPage: WebpageReference(webPage), media: file), streamVideo: isMediaStreamable(media: file) ? .conservative : .none), originData: nil, indexData: indexData, contentInfo: .webPage(webPage, file, nil), caption: caption, credit: credit, fromPlayingVideo: fromPlayingVideo, landscape: landscape, playbackRate: { nil }, performAction: { _ in }, openActionOptions: { _, _ in }, storeMediaPlaybackState: { _, _, _ in }, present: { _, _ in })
            } else {
                var representations: [TelegramMediaImageRepresentation] = []
                representations.append(contentsOf: file.previewRepresentations)
                if let dimensions = file.dimensions {
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
                }
                let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                return InstantImageGalleryItem(context: context, presentationData: presentationData, itemId: self.index, imageReference: .webPage(webPage: WebpageReference(webPage), media: image), caption: caption, credit: credit, location: self.location, openUrl: openUrl, openUrlOptions: openUrlOptions)
            }
        } else if let embedWebpage = self.media.media as? TelegramMediaWebpage, case let .Loaded(webpageContent) = embedWebpage.content {
            if webpageContent.url.hasSuffix(".m3u8") {
                let content = PlatformVideoContent(id: .instantPage(embedWebpage.webpageId, embedWebpage.webpageId), content: .url(webpageContent.url), streamVideo: true, loopVideo: false)
                return UniversalVideoGalleryItem(context: context, presentationData: presentationData, content: content, originData: nil, indexData: nil, contentInfo: .webPage(webPage, embedWebpage, { makeArguments, navigationController, present in
                    let gallery = InstantPageGalleryController(context: context, webPage: webPage, entries: [self], centralIndex: 0, replaceRootController: { [weak navigationController] controller, ready in
                        if let navigationController = navigationController {
                            navigationController.replaceTopController(controller, animated: false, ready: ready)
                        }
                    }, baseNavigationController: navigationController)
                    present(gallery, InstantPageGalleryControllerPresentationArguments(transitionArguments: { entry -> GalleryTransitionArguments? in
                        return makeArguments()
                    }))
                }), caption: NSAttributedString(string: ""), fromPlayingVideo: fromPlayingVideo, landscape: landscape, playbackRate: { nil }, performAction: { _ in }, openActionOptions: { _, _ in }, storeMediaPlaybackState: { _, _, _ in }, present: { _, _ in })
            } else {
                if let content = WebEmbedVideoContent(webPage: embedWebpage, webpageContent: webpageContent, openUrl: { url in
                    
                }) {
                    return UniversalVideoGalleryItem(context: context, presentationData: presentationData, content: content, originData: nil, indexData: nil, contentInfo: .webPage(webPage, embedWebpage, nil), caption: NSAttributedString(string: ""), fromPlayingVideo: fromPlayingVideo, landscape: landscape, playbackRate: { nil }, performAction: { _ in }, openActionOptions: { _, _ in }, storeMediaPlaybackState: { _, _, _ in }, present: { _, _ in })
                } else {
                    preconditionFailure()
                }
            }
        } else {
            preconditionFailure()
        }
    }
}

public final class InstantPageGalleryControllerPresentationArguments {
    let transitionArguments: (InstantPageGalleryEntry) -> GalleryTransitionArguments?
    
    public init(transitionArguments: @escaping (InstantPageGalleryEntry) -> GalleryTransitionArguments?) {
        self.transitionArguments = transitionArguments
    }
}

public class InstantPageGalleryController: ViewController, StandalonePresentableController {
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let context: AccountContext
    private let webPage: TelegramMediaWebpage
    private let message: Message?
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    
    private var entries: [InstantPageGalleryEntry] = []
    private var centralEntryIndex: Int?
    private let fromPlayingVideo: Bool
    private let landscape: Bool
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemRightBarButtonItem = Promise<UIBarButtonItem?>()
    private let centralItemRightBarButtonItems = Promise<[UIBarButtonItem]?>(nil)
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<(GalleryFooterContentNode?, GalleryOverlayContentNode?)>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private let _hiddenMedia = Promise<InstantPageGalleryEntry?>(nil)
    public var hiddenMedia: Signal<InstantPageGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, Promise<Bool>?) -> Void
    private let baseNavigationController: NavigationController?
    
    var openUrl: ((InstantPageUrlItem) -> Void)?
    private var innerOpenUrl: (InstantPageUrlItem) -> Void
    private var openUrlOptions: (InstantPageUrlItem) -> Void
    
    public init(context: AccountContext, webPage: TelegramMediaWebpage, message: Message? = nil, entries: [InstantPageGalleryEntry], centralIndex: Int, fromPlayingVideo: Bool = false, landscape: Bool = false, timecode: Double? = nil, replaceRootController: @escaping (ViewController, Promise<Bool>?) -> Void, baseNavigationController: NavigationController?) {
        self.context = context
        self.webPage = webPage
        self.message = message
        self.fromPlayingVideo = fromPlayingVideo
        self.landscape = landscape
        self.replaceRootController = replaceRootController
        self.baseNavigationController = baseNavigationController
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var openLinkImpl: ((InstantPageUrlItem) -> Void)?
        self.innerOpenUrl = { url in
            openLinkImpl?(url)
        }
        var openLinkOptionsImpl: ((InstantPageUrlItem) -> Void)?
        self.openUrlOptions = { url in
            openLinkOptionsImpl?(url)
        }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: presentationData.strings.Common_Back, target: self, action: #selector(self.donePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.statusBar.statusBarStyle = .White
        
        let entriesSignal: Signal<[InstantPageGalleryEntry], NoError> = .single(entries)
        
        self.disposable.set((entriesSignal |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                strongSelf.entries = entries
                strongSelf.centralEntryIndex = centralIndex
                if strongSelf.isViewLoaded {
                    strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({
                        $0.item(context: context, webPage: webPage, message: message, presentationData: strongSelf.presentationData, fromPlayingVideo: fromPlayingVideo, landscape: landscape, openUrl: strongSelf.innerOpenUrl, openUrlOptions: strongSelf.openUrlOptions)
                    }), centralItemIndex: centralIndex)
                    
                    let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
                        strongSelf?.didSetReady = true
                    }
                    strongSelf._ready.set(ready |> map { true })
                }
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitle.get().start(next: { [weak self] title in
            self?.navigationItem.title = title
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitleView.get().start(next: { [weak self] titleView in
            self?.navigationItem.titleView = titleView
        }))
        
        self.centralItemAttributesDisposable.add(combineLatest(self.centralItemRightBarButtonItem.get(), self.centralItemRightBarButtonItems.get()).start(next: { [weak self] rightBarButtonItem, rightBarButtonItems in
            if let rightBarButtonItem = rightBarButtonItem {
                self?.navigationItem.rightBarButtonItem = rightBarButtonItem
            } else if let rightBarButtonItems = rightBarButtonItems {
                self?.navigationItem.rightBarButtonItems = rightBarButtonItems
            } else {
                self?.navigationItem.rightBarButtonItem = nil
                self?.navigationItem.rightBarButtonItems = nil
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode, _ in
            self?.galleryNode.updatePresentationState({
                $0.withUpdatedFooterContentNode(footerContentNode)
            }, transition: .immediate)
        }))
        
        openLinkImpl = { [weak self] url in
            if let strongSelf = self {
                strongSelf.dismiss(forceAway: false)
                strongSelf.openUrl?(url)
            }
        }
        
        openLinkOptionsImpl = { [weak self] url in
            if let strongSelf = self {
                var presentationData = strongSelf.presentationData
                if !presentationData.theme.overallDarkAppearance {
                    presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                }
                
                let canOpenIn = availableOpenInOptions(context: context, item: .url(url: url.url)).count > 1
                let openText = canOpenIn ? strongSelf.presentationData.strings.Conversation_FileOpenIn : strongSelf.presentationData.strings.Conversation_LinkDialogOpen
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: url.url),
                    ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        openLinkImpl?(url)
                    }),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        UIPasteboard.general.string = url.url
                    }),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let link = URL(string: url.url) {
                            let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                        }
                    })
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                strongSelf.present(actionSheet, in: .window(.root))
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.centralItemAttributesDisposable.dispose()
    }
    
    @objc private func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    private func dismiss(forceAway: Bool) {
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? InstantPageGalleryControllerPresentationArguments {
            if !self.entries.isEmpty {
                if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]), !forceAway {
                    animatedOutNode = false
                    centralItemNode.animateOut(to: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                        animatedOutNode = true
                        completion()
                    })
                }
            }
        }
        
        self.galleryNode.animateOut(animateContent: animatedOutNode, completion: {
            animatedOutInterface = true
            completion()
        })
    }
    
    override public func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
            }
        }, pushController: { _ in
        }, dismissController: { [weak self] in
            self?.dismiss(forceAway: true)
        }, replaceRootController: { [weak self] controller, ready in
            if let strongSelf = self {
                strongSelf.replaceRootController(controller, ready)
            }
        }, editMedia: { _ in
        })
        self.displayNode = GalleryControllerNode(controllerInteraction: controllerInteraction)
        self.displayNodeDidLoad()
        
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        
        self.galleryNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? InstantPageGalleryControllerPresentationArguments {
                    if let transitionArguments = presentationArguments.transitionArguments(strongSelf.entries[centralItemNode.index]) {
                        return (transitionArguments.transitionNode, transitionArguments.addToTransitionSurface)
                    }
                }
            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.completeCustomDismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.pager.replaceItems(self.entries.map({
            $0.item(context: self.context, webPage: self.webPage, message: self.message, presentationData: self.presentationData, fromPlayingVideo: self.fromPlayingVideo, landscape: self.landscape, openUrl: self.innerOpenUrl, openUrlOptions: self.openUrlOptions)
        }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: InstantPageGalleryEntry?
                if let index = index {
                    hiddenItem = strongSelf.entries[index]
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemRightBarButtonItem.set(node.rightBarButtonItem())
                        strongSelf.centralItemRightBarButtonItems.set(node.rightBarButtonItems())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                }
            }
        }
        
        let baseNavigationController = self.baseNavigationController
        self.galleryNode.baseNavigationController = { [weak baseNavigationController] in
            return baseNavigationController
        }
        
        let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
            self?.didSetReady = true
        }
        self._ready.set(ready |> map { true })
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? InstantPageGalleryControllerPresentationArguments {
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemRightBarButtonItem.set(centralItemNode.rightBarButtonItem())
            self.centralItemRightBarButtonItems.set(centralItemNode.rightBarButtonItems())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            
            if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]) {
                nodeAnimatesItself = true
                centralItemNode.activateAsInitial()
                centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {})
                
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
            }
        }
        
        self.galleryNode.animateIn(animateContent: !nodeAnimatesItself, useSimpleAnimation: false)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
