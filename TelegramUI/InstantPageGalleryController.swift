import Foundation
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import SafariServices

struct InstantPageGalleryEntryLocation: Equatable {
    let position: Int32
    let totalCount: Int32
    
    static func ==(lhs: InstantPageGalleryEntryLocation, rhs: InstantPageGalleryEntryLocation) -> Bool {
        return lhs.position == rhs.position && lhs.totalCount == rhs.totalCount
    }
}

struct InstantPageGalleryEntry: Equatable {
    let index: Int32
    let pageId: MediaId
    let media: InstantPageMedia
    let caption: RichText?
    let credit: RichText?
    let location: InstantPageGalleryEntryLocation
    
    static func ==(lhs: InstantPageGalleryEntry, rhs: InstantPageGalleryEntry) -> Bool {
        return lhs.index == rhs.index && lhs.pageId == rhs.pageId && lhs.media == rhs.media && lhs.caption == rhs.caption && lhs.credit == rhs.credit && lhs.location == rhs.location
    }
    
    func item(account: Account, webPage: TelegramMediaWebpage, presentationData: PresentationData, openUrl: @escaping (InstantPageUrlItem) -> Void, openUrlOptions: @escaping (InstantPageUrlItem) -> Void) -> GalleryItem {
        let caption: NSAttributedString
        let credit: NSAttributedString
        
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(16.0))
        styleStack.push(.textColor(.white))
        styleStack.push(.markerColor(UIColor(rgb: 0x313131)))
        styleStack.push(.fontSerif(false))
        
        if let url = self.media.url {
            styleStack.push(.lineSpacingFactor(1.45))
            
            let titleString = RichText.bold(.plain(presentationData.strings.InstantPage_TapToOpenLink + "\n"))
            let urlString = RichText.url(text: .plain(url.url), url: url.url, webpageId: url.webpageId)
            let urlText = RichText.concat([titleString, urlString])
            
            caption = attributedStringForRichText(urlText, styleStack: styleStack)
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
                styleStack.push(.fontSerif(false))
                //styleStack.push(.lineSpacingFactor(1.0))
                credit = attributedStringForRichText(mediaCredit, styleStack: styleStack)
            } else {
                credit = NSAttributedString(string: "")
            }
        }
        
        if let image = self.media.media as? TelegramMediaImage {
            return InstantImageGalleryItem(account: account, presentationData: presentationData, imageReference: .webPage(webPage: WebpageReference(webPage), media: image), caption: caption, credit: credit, location: self.location, openUrl: openUrl, openUrlOptions: openUrlOptions)
        } else if let file = self.media.media as? TelegramMediaFile, file.isVideo {
            return UniversalVideoGalleryItem(account: account, presentationData: presentationData, content: NativeVideoContent(id: .instantPage(self.pageId, file.fileId), fileReference: .webPage(webPage: WebpageReference(webPage), media: file)), originData: nil, indexData: GalleryItemIndexData(position: self.location.position, totalCount: self.location.totalCount), contentInfo: .webPage(webPage, file), caption: caption, credit: credit, openUrl: { _ in }, openUrlOptions: { _ in })
        } else {
            preconditionFailure()
        }
    }
}

final class InstantPageGalleryControllerPresentationArguments {
    let transitionArguments: (InstantPageGalleryEntry) -> GalleryTransitionArguments?
    
    init(transitionArguments: @escaping (InstantPageGalleryEntry) -> GalleryTransitionArguments?) {
        self.transitionArguments = transitionArguments
    }
}

class InstantPageGalleryController: ViewController {
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let account: Account
    private let webPage: TelegramMediaWebpage
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    
    private var entries: [InstantPageGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<GalleryFooterContentNode?>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private let _hiddenMedia = Promise<InstantPageGalleryEntry?>(nil)
    var hiddenMedia: Signal<InstantPageGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, ValuePromise<Bool>?) -> Void
    private let baseNavigationController: NavigationController?
    
    private var openUrl: (InstantPageUrlItem) -> Void
    private var openUrlOptions: (InstantPageUrlItem) -> Void
    
    private let resolveUrlDisposable = MetaDisposable()
    private let loadWebpageDisposable = MetaDisposable()
    
    init(account: Account, webPage: TelegramMediaWebpage, entries: [InstantPageGalleryEntry], centralIndex: Int, replaceRootController: @escaping (ViewController, ValuePromise<Bool>?) -> Void, baseNavigationController: NavigationController?) {
        self.account = account
        self.webPage = webPage
        self.replaceRootController = replaceRootController
        self.baseNavigationController = baseNavigationController
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        var openLinkImpl: ((InstantPageUrlItem) -> Void)?
        self.openUrl = { url in
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
                        $0.item(account: account, webPage: webPage, presentationData: strongSelf.presentationData, openUrl: strongSelf.openUrl, openUrlOptions: strongSelf.openUrlOptions)
                    }), centralItemIndex: centralIndex, keepFirst: false)
                    
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
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode in
            self?.galleryNode.updatePresentationState({
                $0.withUpdatedFooterContentNode(footerContentNode)
            }, transition: .immediate)
        }))
        
        openLinkImpl = { [weak self] url in
            if let strongSelf = self {
                strongSelf.resolveUrlDisposable.set((resolveUrl(account: strongSelf.account, url: url.url) |> deliverOnMainQueue).start(next: { [weak self] result in
                    if let strongSelf = self {
                        let navigationController = strongSelf.baseNavigationController
                        strongSelf.dismiss(forceAway: true)
                        switch result {
                            case let .externalUrl(externalUrl):
                                if let webpageId = url.webpageId {
                                    var anchor: String?
                                    if let anchorRange = externalUrl.range(of: "#") {
                                        anchor = String(externalUrl[anchorRange.upperBound...])
                                    }
                                    strongSelf.loadWebpageDisposable.set((webpagePreview(account: strongSelf.account, url: externalUrl, webpageId: webpageId) |> deliverOnMainQueue).start(next: { webpage in
                                        if let strongSelf = self, let navigationController = navigationController, let webpage = webpage {
                                            navigationController.pushViewController(InstantPageController(account: strongSelf.account, webPage: webpage, anchor: anchor))
                                        }
                                    }))
                                } else {
                                    openExternalUrl(account: strongSelf.account, url: externalUrl, presentationData: strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }, applicationContext: strongSelf.account.telegramApplicationContext, navigationController: navigationController, dismissInput: {
                                        self?.view.endEditing(true)
                                    })
                                }
                            default:
                                openResolvedUrl(result, account: strongSelf.account, navigationController: navigationController, openPeer: { peerId, navigation in
                                    self?.dismiss(forceAway: true)
                                    switch navigation {
                                        case let .chat(_, messageId):
                                            if let navigationController = navigationController {
                                                navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(peerId), messageId: messageId)
                                            }
                                        case .info:
                                            let _ = (strongSelf.account.postbox.loadedPeerWithId(peerId)
                                                |> deliverOnMainQueue).start(next: { peer in
                                                    if let strongSelf = self, let navigationController = navigationController, let controller = peerInfoController(account: strongSelf.account, peer: peer) {
                                                        navigationController.pushViewController(controller)
                                                    }
                                                })
                                        default:
                                            break
                                    }
                                }, present: { c, _ in
                                    self?.present(c, in: .window(.root))
                                }, dismissInput: {
                                    self?.view.endEditing(true)
                                })
                        }
                    }
                }))
            }
        }
        
        openLinkOptionsImpl = { [weak self] url in
            if let strongSelf = self {
                let canOpenIn = availableOpenInOptions(applicationContext: account.telegramApplicationContext, item: .url(url: url.url)).count > 1
                let openText = canOpenIn ? strongSelf.presentationData.strings.Conversation_FileOpenIn : strongSelf.presentationData.strings.Conversation_LinkDialogOpen
                let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
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
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                strongSelf.present(actionSheet, in: .window(.root))
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.resolveUrlDisposable.dispose()
        self.loadWebpageDisposable.dispose()
        self.centralItemAttributesDisposable.dispose()
    }
    
    @objc func donePressed() {
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
    
    override func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments)
            }
            }, dismissController: { [weak self] in
                self?.dismiss(forceAway: true)
            }, replaceRootController: { [weak self] controller, ready in
                if let strongSelf = self {
                    strongSelf.replaceRootController(controller, ready)
                }
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
        
        self.galleryNode.pager.replaceItems(self.entries.map({
            $0.item(account: account, webPage: self.webPage, presentationData: self.presentationData, openUrl: self.openUrl, openUrlOptions: self.openUrlOptions)
        }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: InstantPageGalleryEntry?
                if let index = index {
                    hiddenItem = strongSelf.entries[index]
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                }
            }
        }
        
        let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
            self?.didSetReady = true
        }
        self._ready.set(ready |> map { true })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? InstantPageGalleryControllerPresentationArguments {
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            
            if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]) {
                nodeAnimatesItself = true
                centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface)
                
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
            }
        }
        
        self.galleryNode.animateIn(animateContent: !nodeAnimatesItself)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
