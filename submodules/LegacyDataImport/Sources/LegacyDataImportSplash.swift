import Foundation
import Display
import AsyncDisplayKit
import TelegramPresentationData
import RadialStatusNode

public protocol LegacyDataImportSplash: WindowCoveringView {
    var progress: (AccountImportProgressType, Float) { get set }
    var serviceAction: (() -> Void)? { get set }
}

private final class LegacyDataImportSplashImpl: WindowCoveringView, LegacyDataImportSplash {
    private let theme: PresentationTheme?
    private let strings: PresentationStrings?
    
    public var progress: (AccountImportProgressType, Float) = (.generic, 0.0) {
        didSet {
            if self.progress.0 != oldValue.0 {
                if let size = self.validSize {
                    switch self.progress.0 {
                        case .generic:
                            self.textNode.attributedText = NSAttributedString(string: self.strings?.AppUpgrade_Running ?? "Optimizing...", font: Font.regular(17.0), textColor: self.theme?.list.itemPrimaryTextColor ?? .black)
                        case .media:
                            self.textNode.attributedText = NSAttributedString(string: "Optimizing cache", font: Font.regular(17.0), textColor: self.theme?.list.itemPrimaryTextColor ?? .black)
                        case .messages:
                            self.textNode.attributedText = NSAttributedString(string: "Optimizing database", font: Font.regular(17.0), textColor: self.theme?.list.itemPrimaryTextColor ?? .black)
                    }
                    self.updateLayout(size)
                }
            }
            self.progressNode.transitionToState(.progress(color: self.theme?.list.itemAccentColor ?? UIColor(rgb: 0x007ee5), lineWidth: 2.0, value: CGFloat(max(0.025, self.progress.1)), cancelEnabled: false, animateRotation: true), animated: false, completion: {})
        }
    }
    
    public var serviceAction: (() -> Void)?
    
    private let progressNode: RadialStatusNode
    private let textNode: ImmediateTextNode
    
    private var validSize: CGSize?
    
    public init(theme: PresentationTheme?, strings: PresentationStrings?) {
        self.theme = theme
        self.strings = strings
        
        self.progressNode = RadialStatusNode(backgroundNodeColor: theme?.list.plainBackgroundColor ?? .white)
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        self.textNode.attributedText = NSAttributedString(string: self.strings?.AppUpgrade_Running ?? "Optimizing...", font: Font.regular(17.0), textColor: self.theme?.list.itemPrimaryTextColor ?? .black)
        
        super.init(frame: CGRect())
        
        self.backgroundColor = self.theme?.list.plainBackgroundColor ?? .white
        
        self.addSubnode(self.progressNode)
        self.progressNode.isUserInteractionEnabled = false
        self.addSubnode(self.textNode)
        self.textNode.isUserInteractionEnabled = false
        
        self.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:))))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func updateLayout(_ size: CGSize) {
        self.validSize = size
        
        let progressSize = CGSize(width: 60.0, height: 60.0)
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - 20.0, height: .greatestFiniteMagnitude))
        
        let progressFrame = CGRect(origin: CGPoint(x: floor((size.width - progressSize.width) / 2.0), y: floor((size.height - progressSize.height - 15.0 - textSize.height) / 2.0)), size: progressSize)
        self.progressNode.frame = progressFrame
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: progressFrame.maxY + 15.0), size: textSize)
    }
    
    @objc private func longPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        if case .began = recognizer.state {
            self.serviceAction?()
        }
    }
}

public func makeLegacyDataImportSplash(theme: PresentationTheme?, strings: PresentationStrings?) -> LegacyDataImportSplash {
    return LegacyDataImportSplashImpl(theme: theme, strings: strings)
}
