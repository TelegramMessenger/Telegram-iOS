import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

public struct ShareControllerAction {
    let title: String
    let action: () -> Void
}

public enum ShareControllerExternalStatus {
    case preparing
    case done
}

public enum ShareControllerSubject {
    case url(String)
    case messages([Message])
    case fromExternal(([PeerId], String) -> Signal<ShareControllerExternalStatus, NoError>)
}

private enum ExternalShareItem {
    case text(String)
    case url(URL)
    case image(UIImage)
    case file(URL, String, String)
}

private enum ExternalShareItemStatus {
    case progress
    case done(ExternalShareItem)
}

private enum ExternalShareResourceStatus {
    case progress
    case done(MediaResourceData)
}

private func collectExternalShareResource(postbox: Postbox, resource: MediaResource, tag: MediaResourceFetchTag) -> Signal<ExternalShareResourceStatus, NoError> {
    return Signal { subscriber in
        let fetched = postbox.mediaBox.fetchedResource(resource, tag: tag).start()
        let data = postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false)).start(next: { value in
            if value.complete {
                subscriber.putNext(.done(value))
            } else {
                subscriber.putNext(.progress)
            }
        })
        
        return ActionDisposable {
            fetched.dispose()
            data.dispose()
        }
    }
}

private enum ExternalShareItemsState {
    case progress
    case done([ExternalShareItem])
}

private struct CollectableExternalShareItem {
    let url: String?
    let text: String
    let media: Media?
}

private func collectExternalShareItems(postbox: Postbox, collectableItems: [CollectableExternalShareItem]) -> Signal<ExternalShareItemsState, NoError> {
    var signals: [Signal<ExternalShareItemStatus, NoError>] = []
    for item in collectableItems {
        if let file = item.media as? TelegramMediaFile {
            signals.append(collectExternalShareResource(postbox: postbox, resource: file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .file))
                |> map { next -> ExternalShareItemStatus in
                    switch next {
                        case .progress:
                            return .progress
                        case let .done(data):
                            let fileName: String
                            if let value = file.fileName {
                                fileName = value
                            } else if file.isVideo {
                                fileName = "telegram_video.mp4"
                            } else {
                                fileName = "file"
                            }
                            let randomDirectory = UUID()
                            let safeFileName = fileName.replacingOccurrences(of: "/", with: "_")
                            let fileDirectory = NSTemporaryDirectory() + "\(randomDirectory)"
                            let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: fileDirectory), withIntermediateDirectories: true, attributes: nil)
                            let filePath = fileDirectory + "/\(safeFileName)"
                            if let _ = try? FileManager.default.copyItem(at: URL(fileURLWithPath: data.path), to: URL(fileURLWithPath: filePath)) {
                                return .done(.file(URL(fileURLWithPath: filePath), fileName, file.mimeType))
                            } else {
                                return .progress
                            }
                    }
                })
        } else if let image = item.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
            signals.append(collectExternalShareResource(postbox: postbox, resource: largest.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .image))
                |> map { next -> ExternalShareItemStatus in
                    switch next {
                        case .progress:
                            return .progress
                        case let .done(data):
                            if let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path)), let image = UIImage(data: fileData) {
                                return .done(.image(image))
                            } else {
                                return .progress
                            }
                    }
                })
        }
        if let url = item.url, let parsedUrl = URL(string: url) {
            if signals.isEmpty {
                signals.append(.single(.done(.url(parsedUrl))))
            }
        }
        if !item.text.isEmpty {
            if signals.isEmpty {
                signals.append(.single(.done(.text(item.text))))
            }
        }
    }
    return combineLatest(signals)
        |> map { statuses -> ExternalShareItemsState in
            var items: [ExternalShareItem] = []
            for status in statuses {
                switch status {
                    case .progress:
                        return .progress
                    case let .done(item):
                        items.append(item)
                }
            }
            return .done(items)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if case .progress = lhs, case .progress = rhs {
                return true
            } else {
                return false
            }
        })
}

public final class ShareController: ViewController {
    private var controllerNode: ShareControllerNode {
        return self.displayNode as! ShareControllerNode
    }
    
    private var animatedIn = false
    
    private let account: Account
    private var presentationData: PresentationData
    private let externalShare: Bool
    private let immediateExternalShare: Bool
    private let subject: ShareControllerSubject
    
    private let peers = Promise<[Peer]>()
    private let peersDisposable = MetaDisposable()
    
    private var defaultAction: ShareControllerAction?
    
    public var dismissed: (() -> Void)?
    
    public init(account: Account, subject: ShareControllerSubject, saveToCameraRoll: Bool = false, showInChat: ((Message) -> Void)? = nil, externalShare: Bool = true, immediateExternalShare: Bool = false) {
        self.account = account
        self.externalShare = externalShare
        self.immediateExternalShare = immediateExternalShare
        self.subject = subject
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarTheme: nil)
        
        switch subject {
            case let .url(text):
                self.defaultAction = ShareControllerAction(title: self.presentationData.strings.ShareMenu_CopyShareLink, action: { [weak self] in
                    UIPasteboard.general.string = text
                    self?.controllerNode.cancel?()
                })
            case let .messages(messages):
                if messages.count == 1, let message = messages.first {
                    if saveToCameraRoll {
                        self.defaultAction = ShareControllerAction(title: self.presentationData.strings.Preview_SaveToCameraRoll, action: { [weak self] in
                            self?.saveToCameraRoll(message)
                        })
                    } else if let showInChat = showInChat {
                        self.defaultAction = ShareControllerAction(title: self.presentationData.strings.SharedMedia_ViewInChat, action: { [weak self] in
                            self?.controllerNode.cancel?()
                            showInChat(message)
                        })
                    } else if let chatPeer = message.peers[message.id.peerId] as? TelegramChannel {
                        if message.id.namespace == Namespaces.Message.Cloud, let addressName = chatPeer.addressName, !addressName.isEmpty {
                            self.defaultAction = ShareControllerAction(title: self.presentationData.strings.ShareMenu_CopyShareLink, action: { [weak self] in
                                UIPasteboard.general.string = "https://t.me/\(addressName)/\(message.id.id)"
                                self?.controllerNode.cancel?()
                            })
                        }
                    }
                }
            case .fromExternal:
                break
        }
        
        self.peers.set(combineLatest(account.postbox.loadedPeerWithId(account.peerId) |> take(1), account.viewTracker.tailChatListView(groupId: nil, count: 150) |> take(1)) |> map { accountPeer, view -> [Peer] in
            var peers: [Peer] = []
            peers.append(accountPeer)
            for entry in view.0.entries.reversed() {
                switch entry {
                    case let .MessageEntry(_, message, _, _, _, renderedPeer, _):
                        if let peer = renderedPeer.chatMainPeer, peer.id != accountPeer.id {
                            if canSendMessagesToPeer(peer) {
                                peers.append(peer)
                            }
                        }
                    default:
                        break
                }
            }
            return peers
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.peersDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ShareControllerNode(account: self.account, defaultAction: self.defaultAction, requestLayout: { [weak self] transition in
            self?.requestLayout(transition: transition)
        }, externalShare: self.externalShare, immediateExternalShare: self.immediateExternalShare)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            self?.dismissed?()
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.share = { [weak self] text, peerIds in
            if let strongSelf = self {
                switch strongSelf.subject {
                    case let .url(url):
                        for peerId in peerIds {
                            var messages: [EnqueueMessage] = []
                            if !text.isEmpty {
                                messages.append(.message(text: text, attributes: [], media: nil, replyToMessageId: nil, localGroupingKey: nil))
                            }
                            messages.append(.message(text: url, attributes: [], media: nil, replyToMessageId: nil, localGroupingKey: nil))
                            let _ = enqueueMessages(account: strongSelf.account, peerId: peerId, messages: messages).start()
                        }
                        return .complete()
                    case let .messages(messages):
                        for peerId in peerIds {
                            var messagesToEnqueue: [EnqueueMessage] = []
                            if !text.isEmpty {
                                messagesToEnqueue.append(.message(text: text, attributes: [], media: nil, replyToMessageId: nil, localGroupingKey: nil))
                            }
                            for message in messages {
                                messagesToEnqueue.append(.forward(source: message.id, grouping: .auto))
                            }
                            let _ = enqueueMessages(account: strongSelf.account, peerId: peerId, messages: messagesToEnqueue).start()
                        }
                        return .complete()
                    case let .fromExternal(f):
                        return f(peerIds, text)
                            |> mapToSignal { _ -> Signal<Void, NoError> in
                                return .complete()
                            }
                }
            }
            return .complete()
        }
        self.controllerNode.shareExternal = { [weak self] in
            if let strongSelf = self {
                var collectableItems: [CollectableExternalShareItem] = []
                switch strongSelf.subject {
                    case let .url(text):
                        collectableItems.append(CollectableExternalShareItem(url: text, text: "", media: nil))
                    case let .messages(messages):
                        for message in messages {
                            var url: String?
                            var selectedMedia: Media?
                            loop: for media in message.media {
                                switch media {
                                    case _ as TelegramMediaImage, _ as TelegramMediaFile:
                                        selectedMedia = media
                                        break loop
                                    case let webpage as TelegramMediaWebpage:
                                        if case let .Loaded(content) = webpage.content {
                                            if let file = content.file {
                                                selectedMedia = file
                                            } else if let image = content.image {
                                                selectedMedia = image
                                            }
                                        }
                                    default:
                                        break
                                }
                            }
                            if let chatPeer = message.peers[message.id.peerId] as? TelegramChannel {
                                if message.id.namespace == Namespaces.Message.Cloud, let addressName = chatPeer.addressName, !addressName.isEmpty {
                                    url = "https://t.me/\(addressName)/\(message.id.id)"
                                }
                            }
                            collectableItems.append(CollectableExternalShareItem(url: url, text: message.text, media: selectedMedia))
                        }
                    case .fromExternal:
                        break
                }
                return (collectExternalShareItems(postbox: strongSelf.account.postbox, collectableItems: collectableItems) |> deliverOnMainQueue) |> map { state in
                    switch state {
                        case .progress:
                            return .preparing
                        case let .done(items):
                            if let strongSelf = self, !items.isEmpty {
                                strongSelf.ready.set(.single(true))
                                var activityItems: [Any] = []
                                for item in items {
                                    switch item {
                                        case let .url(url):
                                            activityItems.append(url as NSURL)
                                        case let .text(text):
                                            activityItems.append(text as NSString)
                                        case let .image(image):
                                            activityItems.append(image)
                                        case let .file(url, fileName, mimeType):
                                            activityItems.append(url)
                                    }
                                }
                                let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                                if let window = strongSelf.view.window {
                                    window.rootViewController?.present(activityController, animated: true, completion: nil)
                                }
                            }
                            return .done
                    }
                }
            } else {
                return .single(.done)
            }
        }
        self.displayNodeDidLoad()
        self.peersDisposable.set((self.peers.get() |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePeers(peers: next, defaultAction: strongSelf.defaultAction)
            }
        }))
        self.ready.set(self.controllerNode.ready.get())
    }
    
    override public func loadView() {
        super.loadView()
        
        self.statusBar.removeFromSupernode()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.view.endEditing(true)
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func saveToCameraRoll(_ message: Message) {
        if let media = message.media.first {
            self.controllerNode.transitionToProgress(signal: TelegramUI.saveToCameraRoll(postbox: self.account.postbox, media: media))
        }
    }
}
