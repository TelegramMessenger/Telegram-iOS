import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import Display

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
    private let account: Account
    let initialPeer: Peer
    let safeInset: CGFloat
    private let rtl: Bool
    private var strings: PresentationStrings
    private var theme: InstantPageTheme
    private let openPeer: (PeerId) -> Void
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    private let nameNode: ASTextNode
    private let joinNode: HighlightableButtonNode
    private let activityIndicator: ActivityIndicator
    private let checkNode: ASImageNode
    
    private var peer: Peer?
    private var peerDisposable: Disposable?
    
    private let joinDisposable = MetaDisposable()
    
    private var joinState: JoinState = .none
    
    init(account: Account, strings: PresentationStrings, theme: InstantPageTheme, initialPeer: Peer, safeInset: CGFloat, rtl: Bool, openPeer: @escaping (PeerId) -> Void) {
        self.account = account
        self.strings = strings
        self.theme = theme
        self.initialPeer = initialPeer
        self.safeInset = safeInset
        self.rtl = rtl
        self.openPeer = openPeer
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.backgroundColor = theme.panelHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightableButtonNode()
        
        self.nameNode = ASTextNode()
        self.nameNode.isLayerBacked = true
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
        
        self.backgroundColor = theme.panelBackgroundColor
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
        
        self.peerDisposable = (actualizedPeer(postbox: self.account.postbox, network: self.account.network, peer: self.initialPeer) |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self {
                strongSelf.nameNode.attributedText = NSAttributedString(string: peer.displayTitle, font: Font.medium(17.0), textColor: strongSelf.theme.panelPrimaryColor)
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
            self.nameNode.attributedText = NSAttributedString(string: peer.displayTitle, font: Font.medium(17.0), textColor: self.theme.panelPrimaryColor)
        }
        self.joinNode.setAttributedTitle(NSAttributedString(string: self.strings.Channel_JoinChannel, font: Font.medium(17.0), textColor: self.theme.panelAccentColor), for: [])
        
        if themeUpdated {
            self.checkNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/PanelCheck"), color: self.theme.panelSecondaryColor)
            self.activityIndicator.type = .custom(self.theme.panelAccentColor, 22.0, 2.0, false)
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
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    @objc func buttonPressed() {
        self.openPeer(self.initialPeer.id)
    }
    
    @objc func joinPressed() {
        if case .notJoined = self.joinState {
            self.updateJoinState(.inProgress)
            self.joinDisposable.set((joinChannel(account: self.account, peerId: self.initialPeer.id) |> deliverOnMainQueue).start(error: { [weak self] _ in
                if let strongSelf = self {
                    if case .inProgress = strongSelf.joinState {
                        strongSelf.updateJoinState(.notJoined)
                    }
                }
            }))
        }
    }
}
