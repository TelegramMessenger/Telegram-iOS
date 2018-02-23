import Foundation
import UIKit
import AsyncDisplayKit
import Display

struct NetworkStatusTitle: Equatable {
    let text: String
    let activity: Bool
    
    static func ==(lhs: NetworkStatusTitle, rhs: NetworkStatusTitle) -> Bool {
        return lhs.text == rhs.text && lhs.activity == rhs.activity
    }
}

final class NetworkStatusTitleView: UIView, NavigationBarTitleTransitionNode {
    private let titleNode: ASTextNode
    private let lockView: ChatListTitleLockView
    private let activityIndicator: ActivityIndicator
    private let buttonView: HighlightTrackingButton
    
    var title: NetworkStatusTitle = NetworkStatusTitle(text: "", activity: false) {
        didSet {
            if self.title != oldValue {
                self.titleNode.attributedText = NSAttributedString(string: title.text, font: Font.bold(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                if self.title.activity != oldValue.activity {
                    if self.title.activity {
                        if self.activityIndicator.layer.superlayer == nil {
                            self.addSubnode(self.activityIndicator)
                        }
                    } else {
                        if self.activityIndicator.layer.superlayer != nil {
                            self.activityIndicator.removeFromSupernode()
                        }
                    }
                }
                self.setNeedsLayout()
            }
        }
    }
    
    var toggleIsLocked: (() -> Void)?
    
    private var isPasscodeSet = false
    private var isManuallyLocked = false
    
    var theme: PresentationTheme {
        didSet {
            self.titleNode.attributedText = NSAttributedString(string: self.title.text, font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
            
            if self.isPasscodeSet {
                self.lockView.setIsLocked(self.isManuallyLocked, theme: self.theme, animated: false)
            } else {
                self.lockView.setIsLocked(false, theme: self.theme, animated: false)
            }
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        self.titleNode.isUserInteractionEnabled = false
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.rootController.navigationBar.primaryTextColor, 22.0, 1.5), speed: .slow)
        let activityIndicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        self.activityIndicator.frame = CGRect(origin: CGPoint(), size: activityIndicatorSize)
        
        self.lockView = ChatListTitleLockView(frame: CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: 2.0)))
        self.lockView.isHidden = true
        self.lockView.isUserInteractionEnabled = false
        
        self.buttonView = HighlightTrackingButton()
        
        super.init(frame: CGRect())
        
        self.addSubview(self.buttonView)
        self.addSubnode(self.titleNode)
        self.addSubview(self.lockView)
        
        self.buttonView.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted && (strongSelf.activityIndicator.isHidden || strongSelf.activityIndicator.layer.superlayer == nil) {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.lockView.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.lockView.alpha = 0.4
                } else if !strongSelf.titleNode.alpha.isEqual(to: 1.0) {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.lockView.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.lockView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.buttonView.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        var indicatorPadding: CGFloat = 0.0
        let indicatorSize = self.activityIndicator.bounds.size
        
        if self.activityIndicator.layer.superlayer != nil {
            indicatorPadding = indicatorSize.width + 6.0
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: max(1.0, size.width - indicatorPadding), height: size.height))
        let combinedHeight = titleSize.height
        
        let titleFrame = CGRect(origin: CGPoint(x: indicatorPadding + floor((size.width - titleSize.width - indicatorPadding) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
        
        let buttonX = max(0.0, titleFrame.minX - 10.0)
        self.buttonView.frame = CGRect(origin: CGPoint(x: buttonX, y: 0.0), size: CGSize(width: min(titleFrame.maxX + 28.0, size.width) - buttonX, height: size.height))
        
        self.lockView.frame = CGRect(x: titleFrame.maxX + 6.0, y: titleFrame.minY + 4.0, width: 2.0, height: 2.0)
        
        if self.activityIndicator.layer.superlayer != nil {
            self.activityIndicator.frame = CGRect(origin: CGPoint(x: titleFrame.minX - indicatorSize.width - 6.0, y: titleFrame.minY - 1.0), size: indicatorSize)
        }
    }
    
    func updatePasscode(isPasscodeSet: Bool, isManuallyLocked: Bool) {
        if self.isPasscodeSet == isPasscodeSet && self.isManuallyLocked == isManuallyLocked {
            return
        }
        
        self.isPasscodeSet = isPasscodeSet
        self.isManuallyLocked = isManuallyLocked
        
        if isPasscodeSet {
            self.buttonView.isHidden = false
            self.lockView.isHidden = false
            self.lockView.setIsLocked(isManuallyLocked, theme: self.theme, animated: !self.bounds.size.width.isZero)
        } else {
            self.buttonView.isHidden = true
            self.lockView.isHidden = true
            self.lockView.setIsLocked(false, theme: self.theme, animated: false)
        }
    }
    
    @objc func buttonPressed() {
        self.toggleIsLocked?()
    }
    
    func makeTransitionMirrorNode() -> ASDisplayNode {
        let view = NetworkStatusTitleView(theme: self.theme)
        view.title = self.title
        
        return ASDisplayNode(viewBlock: {
            return view
        }, didLoad: nil)
    }
}
