import Foundation
import UIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import ActivityIndicator
import AccountContext
import AppBundle

private enum JoinState: Equatable {
    case none
    case notJoined
    case inProgress
    case joined(justNow: Bool)
    
    static func ==(lhs: JoinState, rhs: JoinState) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case .notJoined:
                if case .notJoined = rhs {
                    return true
                } else {
                    return false
                }
            case .inProgress:
                if case .inProgress = rhs {
                    return true
                } else {
                    return false
                }
            case let .joined(justNow):
                if case .joined(justNow) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class InstantPagePeerReferenceNode: ASDisplayNode, InstantPageNode {
    private let context: AccountContext
    let safeInset: CGFloat
    private let transparent: Bool
    private let rtl: Bool
    private var strings: PresentationStrings
    private var nameDisplayOrder: PresentationPersonNameOrder
    private var theme: InstantPageTheme
    private let openPeer: (PeerId) -> Void
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    private let nameNode: ASTextNode
    private let joinNode: HighlightableButtonNode
    private let activityIndicator: ActivityIndicator
    private let checkNode: ASImageNode
    
    var peer: Peer?
    private var peerDisposable: Disposable?
    
    private let joinDisposable = MetaDisposable()
    private var joinState: JoinState = .none
    
    init(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, initialPeer: Peer, safeInset: CGFloat, transparent: Bool, rtl: Bool, openPeer: @escaping (PeerId) -> Void) {
        self.context = context
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.theme = theme
        self.peer = initialPeer
        self.safeInset = safeInset
        self.transparent = transparent
        self.rtl = rtl
        self.openPeer = openPeer
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightableButtonNode()
        
        self.nameNode = ASTextNode()
        self.nameNode.isUserInteractionEnabled = false
        self.nameNode.maximumNumberOfLines = 1
        
        self.joinNode = HighlightableButtonNode()
        self.joinNode.hitTestSlop = UIEdgeInsets(top: -17.0, left: -17.0, bottom: -17.0, right: -17.0)
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.panelAccentColor, 22.0, 2.0, false))
        
        self.checkNode = ASImageNode()
        self.checkNode.isLayerBacked = true
        self.checkNode.displayWithoutProcessing = true
        self.checkNode.displaysAsynchronously = false
        self.checkNode.isHidden = true
        
        super.init()
        
        if self.transparent {
            self.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
            self.highlightedBackgroundNode.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        } else {
            self.backgroundColor = theme.panelBackgroundColor
            self.highlightedBackgroundNode.backgroundColor = theme.panelHighlightedBackgroundColor
        }
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.joinNode)
        self.addSubnode(self.checkNode)
        self.addSubnode(self.nameNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        
        self.joinNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.joinNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.joinNode.alpha = 0.4
                } else {
                    strongSelf.joinNode.alpha = 1.0
                    strongSelf.joinNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.joinNode.addTarget(self, action: #selector(self.joinPressed), forControlEvents: .touchUpInside)
        
        let account = self.context.account
        let context = self.context
        let signal = actualizedPeer(postbox: account.postbox, network: account.network, peer: initialPeer)
        |> mapToSignal({ peer -> Signal<Peer, NoError> in
            if let peer = peer as? TelegramChannel, let username = peer.username, peer.accessHash == nil {
                return .single(peer) |> then(context.engine.peers.resolvePeerByName(name: username)
                |> mapToSignal({ updatedPeer -> Signal<Peer, NoError> in
                    if let updatedPeer = updatedPeer {
                        return .single(updatedPeer._asPeer())
                    } else {
                        return .single(peer)
                    }
                }))
            } else {
                return .single(peer)
            }
        })
    
        self.peerDisposable = (signal |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self {
                strongSelf.peer = peer
                if let peer = peer as? TelegramChannel {
                    var joinState = strongSelf.joinState
                    if case .member = peer.participationStatus {
                        switch joinState {
                            case .none:
                                joinState = .joined(justNow: false)
                            case .inProgress, .notJoined:
                                joinState = .joined(justNow: true)
                            case .joined:
                                break
                        }
                    } else {
                        joinState = .notJoined
                    }
                    strongSelf.updateJoinState(joinState)
                }
                strongSelf.applyThemeAndStrings(themeUpdated: false)
                strongSelf.setNeedsLayout()
            }
        })
        
        self.applyThemeAndStrings(themeUpdated: true)
    }
    
    deinit {
        self.peerDisposable?.dispose()
        self.joinDisposable.dispose()
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        if self.strings !== strings || self.theme !== theme {
            let themeUpdated = self.theme !== theme
            self.strings = strings
            self.theme = theme
            self.applyThemeAndStrings(themeUpdated: themeUpdated)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    private func applyThemeAndStrings(themeUpdated: Bool) {
        if let peer = self.peer {
            let textColor = self.transparent ? UIColor.white : self.theme.panelPrimaryColor
            self.nameNode.attributedText = NSAttributedString(string: EnginePeer(peer).displayTitle(strings: self.strings, displayOrder: self.nameDisplayOrder), font: Font.medium(17.0), textColor: textColor)
        }
        let accentColor = self.transparent ? UIColor.white : self.theme.panelAccentColor
        self.joinNode.setAttributedTitle(NSAttributedString(string: self.strings.Channel_JoinChannel, font: Font.medium(17.0), textColor: accentColor), for: [])
        
        if themeUpdated {
            let secondaryColor = self.transparent ? UIColor.white : self.theme.panelSecondaryColor
            self.checkNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/PanelCheck"), color: secondaryColor)
            self.activityIndicator.type = .custom(self.theme.panelAccentColor, 22.0, 2.0, false)
            
            if !self.transparent {
                self.backgroundColor = self.theme.panelBackgroundColor
                self.highlightedBackgroundNode.backgroundColor = self.theme.panelHighlightedBackgroundColor
            }
        }
        self.setNeedsLayout()
    }
    
    private func updateJoinState(_ joinState: JoinState) {
        if self.joinState != joinState {
            self.joinState = joinState
            
            switch joinState {
                case .none:
                    self.joinNode.isHidden = true
                    self.checkNode.isHidden = true
                    if self.activityIndicator.supernode != nil {
                        self.activityIndicator.removeFromSupernode()
                    }
                case .notJoined:
                    self.joinNode.isHidden = false
                    self.checkNode.isHidden = true
                    if self.activityIndicator.supernode != nil {
                        self.activityIndicator.removeFromSupernode()
                    }
                case .inProgress:
                    self.joinNode.isHidden = true
                    self.checkNode.isHidden = true
                    if self.activityIndicator.supernode == nil {
                        self.addSubnode(self.activityIndicator)
                    }
                case let .joined(justNow):
                    self.joinNode.isHidden = true
                    self.checkNode.isHidden = !justNow
                    if self.activityIndicator.supernode != nil {
                        self.activityIndicator.removeFromSupernode()
                    }
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset: CGFloat = 17.0 + safeInset
        
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        
        let joinSize = self.joinNode.measure(size)
        let nameSize = self.nameNode.measure(CGSize(width: size.width - inset * 2.0 - joinSize.width, height: size.height))
        let checkSize = self.checkNode.measure(size)
        let indicatorSize = self.activityIndicator.measure(size)
        
        if self.rtl {
            self.nameNode.frame = CGRect(origin: CGPoint(x: size.width - inset - nameSize.width, y: floor((size.height - nameSize.height) / 2.0)), size: nameSize)
            self.joinNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((size.height - joinSize.height) / 2.0)), size: joinSize)
            self.checkNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((size.height - checkSize.height) / 2.0)), size: checkSize)
            self.activityIndicator.frame = CGRect(origin: CGPoint(x: inset, y: floor((size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
        } else {
            self.nameNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((size.height - nameSize.height) / 2.0)), size: nameSize)
            self.joinNode.frame = CGRect(origin: CGPoint(x: size.width - inset - joinSize.width, y: floor((size.height - joinSize.height) / 2.0)), size: joinSize)
            self.checkNode.frame = CGRect(origin: CGPoint(x: size.width - inset - checkSize.width, y: floor((size.height - checkSize.height) / 2.0)), size: checkSize)
            self.activityIndicator.frame = CGRect(origin: CGPoint(x: size.width - inset - indicatorSize.width, y: floor((size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    @objc func buttonPressed() {
        if let peer = self.peer {
            self.openPeer(peer.id)
        }
    }
    
    @objc func joinPressed() {
        if let peer = self.peer, case .notJoined = self.joinState {
            self.updateJoinState(.inProgress)
            self.joinDisposable.set((self.context.engine.peers.joinChannel(peerId: peer.id, hash: nil) |> deliverOnMainQueue).start(error: { [weak self] _ in
                if let strongSelf = self {
                    if case .inProgress = strongSelf.joinState {
                        strongSelf.updateJoinState(.notJoined)
                    }
                }
            }))
        }
    }
}
