import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ActivityIndicator

private let titleFont = Font.with(size: 17.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers])

struct NetworkStatusTitle: Equatable {
    let text: String
    let activity: Bool
    let hasProxy: Bool
    let connectsViaProxy: Bool
    let isPasscodeSet: Bool
    let isManuallyLocked: Bool
}

final class ChatListTitleView: UIView, NavigationBarTitleView, NavigationBarTitleTransitionNode {
    private let titleNode: ImmediateTextNode
    private let lockView: ChatListTitleLockView
    private weak var lockSnapshotView: UIView?
    private let activityIndicator: ActivityIndicator
    private let buttonView: HighlightTrackingButton
    private let proxyNode: ChatTitleProxyNode
    private let proxyButton: HighlightTrackingButton
    
    private var validLayout: (CGSize, CGRect)?
    
    private var _title: NetworkStatusTitle = NetworkStatusTitle(text: "", activity: false, hasProxy: false, connectsViaProxy: false, isPasscodeSet: false, isManuallyLocked: false)
    var title: NetworkStatusTitle {
        get {
            return self._title
        }
        set {
            self.setTitle(newValue, animated: false)
        }
    }
    
    func setTitle(_ title: NetworkStatusTitle, animated: Bool) {
        let oldValue = self._title
        self._title = title
        
        if self._title != oldValue {
            self.titleNode.attributedText = NSAttributedString(string: self.title.text, font: titleFont, textColor: self.theme.rootController.navigationBar.primaryTextColor)
            self.buttonView.accessibilityLabel = self.title.text
            self.activityIndicator.isHidden = !self.title.activity
           
            self.proxyButton.isHidden = !self.title.hasProxy
            if self.title.connectsViaProxy {
                self.proxyNode.status = self.title.activity ? .connecting : .connected
            } else {
                self.proxyNode.status = .available
            }
            
            let proxyIsHidden = !self.title.hasProxy
            let previousProxyIsHidden = self.proxyNode.isHidden
            if proxyIsHidden != previousProxyIsHidden {
                if proxyIsHidden {
                    if let snapshotView = self.proxyNode.view.snapshotContentTree() {
                        snapshotView.frame = self.proxyNode.frame
                        self.proxyNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.proxyNode.view)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                } else {
                    self.proxyNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
            }
            self.proxyNode.isHidden = !self.title.hasProxy
            
            self.buttonView.isHidden = !self.title.isPasscodeSet
            if self.title.isPasscodeSet && !self.title.activity {
                if self.lockView.isHidden && animated {
                    self.lockView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
                self.lockView.isHidden = false
            } else {
                if !self.lockView.isHidden && animated {
                    if let snapshotView = self.lockView.snapshotContentTree() {
                        self.lockSnapshotView = snapshotView
                        snapshotView.frame = self.lockView.frame
                        self.lockView.superview?.insertSubview(snapshotView, aboveSubview: self.lockView)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
                self.lockView.isHidden = true
            }
            self.lockView.updateTheme(self.theme)
            
            self.setNeedsLayout()
        }
    }
    
    var toggleIsLocked: (() -> Void)?
    var openProxySettings: (() -> Void)?
    
    private var isPasscodeSet = false
    private var isManuallyLocked = false
    
    var theme: PresentationTheme {
        didSet {
            self.titleNode.attributedText = NSAttributedString(string: self.title.text, font: titleFont, textColor: self.theme.rootController.navigationBar.primaryTextColor)
            
            self.lockView.updateTheme(self.theme)
            
            self.activityIndicator.type = .custom(self.theme.rootController.navigationBar.primaryTextColor, 22.0, 1.5, false)
            self.proxyNode.theme = self.theme
        }
    }
    
    var strings: PresentationStrings {
        didSet {
            self.proxyButton.accessibilityLabel = self.strings.VoiceOver_Navigation_ProxySettings
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationType = .end
        self.titleNode.isOpaque = false
        self.titleNode.isUserInteractionEnabled = false
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.rootController.navigationBar.primaryTextColor, 22.0, 1.5, false), speed: .slow)
        let activityIndicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        self.activityIndicator.frame = CGRect(origin: CGPoint(), size: activityIndicatorSize)
        
        self.lockView = ChatListTitleLockView(frame: CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: 2.0)))
        self.lockView.isHidden = true
        self.lockView.isUserInteractionEnabled = false
        
        self.proxyNode = ChatTitleProxyNode(theme: self.theme)
        self.proxyNode.isHidden = true
        
        self.buttonView = HighlightTrackingButton()
        self.buttonView.isAccessibilityElement = true
        self.buttonView.accessibilityTraits = .header
        
        self.proxyButton = HighlightTrackingButton()
        self.proxyButton.isHidden = true
        self.proxyButton.isAccessibilityElement = true
        self.proxyButton.accessibilityLabel = self.strings.VoiceOver_Navigation_ProxySettings
        self.proxyButton.accessibilityTraits = .button
        
        super.init(frame: CGRect())
        
        self.isAccessibilityElement = false
        
        self.addSubnode(self.activityIndicator)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.proxyNode)
        self.addSubview(self.lockView)
        self.addSubview(self.buttonView)
        self.addSubview(self.proxyButton)
        
        self.buttonView.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted && !strongSelf.lockView.isHidden && strongSelf.activityIndicator.isHidden {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.lockView.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.lockView.alpha = 0.4
                } else {
                    if !strongSelf.titleNode.alpha.isEqual(to: 1.0) {
                        strongSelf.titleNode.alpha = 1.0
                        strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                    if !strongSelf.lockView.alpha.isEqual(to: 1.0) {
                        strongSelf.lockView.alpha = 1.0
                        strongSelf.lockView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                }
            }
        }
        
        self.buttonView.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        
        self.proxyButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.proxyNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.proxyNode.alpha = 0.4
                } else {
                    if !strongSelf.proxyNode.alpha.isEqual(to: 1.0) {
                        strongSelf.proxyNode.alpha = 1.0
                        strongSelf.proxyNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                }
            }
        }
        
        self.proxyButton.addTarget(self, action: #selector(self.proxyButtonPressed), for: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let (size, clearBounds) = self.validLayout {
            self.updateLayout(size: size, clearBounds: clearBounds, transition: .immediate)
        }
    }
    
    func updateLayout(size: CGSize, clearBounds: CGRect, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, clearBounds)
        
        var indicatorPadding: CGFloat = 0.0
        let indicatorSize = self.activityIndicator.bounds.size
        
        if !self.activityIndicator.isHidden {
            indicatorPadding = indicatorSize.width + 6.0
        }
        var maxTitleWidth = clearBounds.size.width - indicatorPadding
        var proxyPadding: CGFloat = 0.0
        if !self.proxyNode.isHidden {
            maxTitleWidth -= 25.0
            proxyPadding += 39.0
        }
        if !self.lockView.isHidden {
            maxTitleWidth -= 10.0
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, maxTitleWidth), height: size.height))
        
        let combinedHeight = titleSize.height
        
        var titleContentRect = CGRect(origin: CGPoint(x: indicatorPadding + floor((size.width - titleSize.width - indicatorPadding) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
        titleContentRect.origin.x = min(titleContentRect.origin.x, clearBounds.maxX - proxyPadding - titleContentRect.width)
        
        let titleFrame = titleContentRect
        var titleTransition = transition
        if self.titleNode.frame.size != titleFrame.size {
            titleTransition = .immediate
        }
        titleTransition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let proxyFrame = CGRect(origin: CGPoint(x: clearBounds.maxX - 9.0 - self.proxyNode.bounds.width, y: floor((size.height - self.proxyNode.bounds.height) / 2.0)), size: self.proxyNode.bounds.size)
        self.proxyNode.frame = proxyFrame
        
        self.proxyButton.frame = proxyFrame.insetBy(dx: -2.0, dy: -2.0)
        
        let buttonX = max(0.0, titleFrame.minX - 10.0)
        self.buttonView.frame = CGRect(origin: CGPoint(x: buttonX, y: 0.0), size: CGSize(width: min(titleFrame.maxX + 28.0, size.width) - buttonX, height: size.height))
        
        let lockFrame = CGRect(x: titleFrame.maxX + 6.0, y: titleFrame.minY + 2.0, width: 2.0, height: 2.0)
        transition.updateFrame(view: self.lockView, frame: lockFrame)
        if let lockSnapshotView = self.lockSnapshotView {
            transition.updateFrame(view: lockSnapshotView, frame: lockFrame)
        }
        
        let activityIndicatorFrame = CGRect(origin: CGPoint(x: titleFrame.minX - indicatorSize.width - 4.0, y: titleFrame.minY - 1.0), size: indicatorSize)
        transition.updateFrame(node: self.activityIndicator, frame: activityIndicatorFrame)
    }
    
    @objc private func buttonPressed() {
        self.toggleIsLocked?()
    }
    
    @objc private func proxyButtonPressed() {
        self.openProxySettings?()
    }
    
    func makeTransitionMirrorNode() -> ASDisplayNode {
        let view = ChatListTitleView(theme: self.theme, strings: self.strings)
        view.title = self.title
        
        return ASDisplayNode(viewBlock: {
            return view
        }, didLoad: nil)
    }
    
    func animateLayoutTransition() {
    }
    
    var proxyButtonFrame: CGRect? {
        if !self.proxyNode.isHidden {
            return proxyNode.frame
        }
        return nil
    }
    
    var lockViewFrame: CGRect? {
        if !self.lockView.isHidden && !self.lockView.frame.isEmpty {
            return self.lockView.frame
        } else {
            return nil
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.proxyButton.isHidden {
            if let result = self.proxyButton.hitTest(point.offsetBy(dx: -self.proxyButton.frame.minX, dy: -self.proxyButton.frame.minY), with: event) {
                return result;
            }
        }
        return super.hitTest(point, with: event)
    }
}
