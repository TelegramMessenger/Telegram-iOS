import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let trendingGifsPromise = Promise<[FileMediaReference]?>(nil)

final class GifPaneSearchContentNode: ASDisplayNode & PaneSearchContentNode {
    private let context: AccountContext
    private let controllerInteraction: ChatControllerInteraction
    private let inputNodeInteraction: ChatMediaInputNodeInteraction
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private var multiplexedNode: MultiplexedVideoNode?
    private let notFoundNode: ASImageNode
    private let notFoundLabel: ImmediateTextNode
    
    private var validLayout: CGSize?
    
    private let searchDisposable = MetaDisposable()
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    var deactivateSearchBar: (() -> Void)?
    var updateActivity: ((Bool) -> Void)?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        self.inputNodeInteraction = inputNodeInteraction
        
        self.theme = theme
        self.strings = strings
        
        self.notFoundNode = ASImageNode()
        self.notFoundNode.displayWithoutProcessing = true
        self.notFoundNode.displaysAsynchronously = false
        self.notFoundNode.clipsToBounds = false
        
        self.notFoundLabel = ImmediateTextNode()
        self.notFoundLabel.displaysAsynchronously = false
        self.notFoundLabel.isUserInteractionEnabled = false
        self.notFoundNode.addSubnode(self.notFoundLabel)
        
        super.init()
        
        self.notFoundNode.isHidden = true
        
        let _ = (trendingGifsPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { next in
            if next == nil {
                trendingGifsPromise.set(self.signalForQuery(""))
            }
        })
        
        self._ready.set(.single(Void()))
        
        self.addSubnode(self.notFoundNode)
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    deinit {
        self.searchDisposable.dispose()
    }
    
    func updateText(_ text: String) {
        let signal: Signal<[FileMediaReference]?, NoError>
        if !text.isEmpty {
            signal = self.signalForQuery(text)
            self.updateActivity?(true)
        } else {
            signal = trendingGifsPromise.get()
            self.updateActivity?(false)
        }
        
        self.searchDisposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self, let result = result else {
                return
            }
            
            strongSelf.multiplexedNode?.files = result
            strongSelf.updateActivity?(false)
            strongSelf.notFoundNode.isHidden = text.isEmpty || !result.isEmpty
        }))
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.notFoundNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/StickersNotFoundIcon"), color: theme.list.freeMonoIcon)
        self.notFoundLabel.attributedText = NSAttributedString(string: strings.Gif_NoGifsFound, font: Font.medium(14.0), textColor: theme.list.freeTextColor)
    }
    
    func updatePreviewing(animated: Bool) {
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, StickerPreviewPeekItem)? {
        return nil
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil
        self.validLayout = size
        
        if let image = self.notFoundNode.image {
            let areaHeight = size.height - inputHeight

            let labelSize = self.notFoundLabel.updateLayout(CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude))

            transition.updateFrame(node: self.notFoundNode, frame: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((areaHeight - image.size.height - labelSize.height) / 2.0)), size: image.size))
            transition.updateFrame(node: self.notFoundLabel, frame: CGRect(origin: CGPoint(x: floor((image.size.width - labelSize.width) / 2.0), y: image.size.height + 8.0), size: labelSize))
        }
        
        if let multiplexedNode = self.multiplexedNode {
            multiplexedNode.topInset = 0.0
            multiplexedNode.bottomInset = 0.0
            let nodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            
            transition.updateFrame(layer: multiplexedNode.layer, frame: nodeFrame)
            multiplexedNode.updateLayout(size: nodeFrame.size, transition: transition)
        }
        
        if firstLayout {
            self.updateText("")
        }
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        if self.multiplexedNode == nil {
            let multiplexedNode = MultiplexedVideoNode(account: self.context.account)
            self.multiplexedNode = multiplexedNode
            if let layout = self.validLayout {
                multiplexedNode.frame = CGRect(origin: CGPoint(), size: layout)
            }
            
            self.view.addSubview(multiplexedNode)
            
            multiplexedNode.fileSelected = { [weak self] fileReference in
                self?.controllerInteraction.sendGif(fileReference)
            }
            
            multiplexedNode.didScroll = { [weak self] offset, height in
                self?.deactivateSearchBar?()
            }
        }
    }
    
    func animateIn(additivePosition: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let multiplexedNode = self.multiplexedNode else {
            return
        }
        
        multiplexedNode.alpha = 0.0
        transition.updateAlpha(layer: multiplexedNode.layer, alpha: 1.0, completion: { _ in
        })

        if case let .animated(duration, curve) = transition {
            multiplexedNode.layer.animatePosition(from: CGPoint(x: 0.0, y: additivePosition), to: CGPoint(), duration: duration, timingFunction: curve.timingFunction, additive: true)
        }
    }
    
    func animateOut(transition: ContainedViewLayoutTransition) {
        guard let multiplexedNode = self.multiplexedNode else {
            return
        }
        
        transition.updateAlpha(layer: multiplexedNode.layer, alpha: 0.0, completion: { _ in
        })
    }
    
    private func signalForQuery(_ query: String) -> Signal<[FileMediaReference]?, NoError> {
        let delayRequest = true

        let account = self.context.account
        let contextBot = resolvePeerByName(account: account, name: "gif")
        |> mapToSignal { peerId -> Signal<Peer?, NoError> in
            if let peerId = peerId {
            return account.postbox.loadedPeerWithId(peerId)
                |> map { peer -> Peer? in
                    return peer
                }
                |> take(1)
            } else {
                return .single(nil)
            }
        }
        |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> in
            if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                let results = requestContextResults(account: account, botId: user.id, query: query, peerId: self.context.account.peerId, limit: 64)
                |> map { results -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in
                        return .contextRequestResult(user, results)
                    }
                }
                
                let botResult: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .single({ previousResult in
                    var passthroughPreviousResult: ChatContextResultCollection?
                    if let previousResult = previousResult {
                        if case let .contextRequestResult(previousUser, previousResults) = previousResult {
                            if previousUser?.id == user.id {
                                passthroughPreviousResult = previousResults
                            }
                        }
                    }
                    return .contextRequestResult(nil, passthroughPreviousResult)
                })
                
                let maybeDelayedContextResults: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>
                if delayRequest {
                    maybeDelayedContextResults = results |> delay(0.4, queue: Queue.concurrentDefaultQueue())
                } else {
                    maybeDelayedContextResults = results
                }
                
                return botResult |> then(maybeDelayedContextResults)
            } else {
                return .single({ _ in return nil })
            }
        }
        return contextBot
        |> mapToSignal { result -> Signal<[FileMediaReference]?, NoError> in
            if let r = result(nil), case let .contextRequestResult(_, collection) = r, let results = collection?.results {
                var references: [FileMediaReference] = []
                for result in results {
                    switch result {
                        case let .internalReference(_, _, _, _, _, _, file, _):
                            if let file = file {
                                references.append(FileMediaReference.standalone(media: file))
                            }
                        default:
                            break
                    }
                }
                return .single(references)
            } else {
                return .complete()
            }
        }
        |> deliverOnMainQueue
        |> beforeStarted { [weak self] in
            self?.updateActivity?(true)
        }
        |> afterCompleted { [weak self] in
            self?.updateActivity?(false)
        }
    }
}
