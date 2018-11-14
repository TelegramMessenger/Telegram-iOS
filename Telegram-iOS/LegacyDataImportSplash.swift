import Foundation
import Display
import AsyncDisplayKit
import TelegramUI

final class LegacyDataImportSplash: WindowCoveringView {
    var progress: (AccountImportProgressType, Float) = (.generic, 0.0) {
        didSet {
            if self.progress.0 != oldValue.0 {
                if let size = self.validSize {
                    switch self.progress.0 {
                        case .generic:
                            self.textNode.attributedText = NSAttributedString(string: "Optimizing", font: Font.regular(17.0), textColor: .black)
                        case .media:
                            self.textNode.attributedText = NSAttributedString(string: "Optimizing cache", font: Font.regular(17.0), textColor: .black)
                        case .messages:
                            self.textNode.attributedText = NSAttributedString(string: "Optimizing database", font: Font.regular(17.0), textColor: .black)
                    }
                    self.updateLayout(size)
                }
            }
            self.progressNode.transitionToState(.progress(color: UIColor(rgb: 0x007ee5), lineWidth: 2.0, value: CGFloat(max(0.025, self.progress.1)), cancelEnabled: false), animated: false, completion: {})
        }
    }
    
    var serviceAction: (() -> Void)?
    
    private let progressNode: RadialStatusNode
    private let textNode: ImmediateTextNode
    
    private var validSize: CGSize?
    
    override init(frame: CGRect) {
        self.progressNode = RadialStatusNode(backgroundNodeColor: UIColor.white)
        self.textNode = ImmediateTextNode()
        self.textNode.attributedText = NSAttributedString(string: "Optimizing", font: Font.regular(17.0), textColor: .black)
        
        super.init(frame: frame)
        
        self.addSubnode(self.progressNode)
        self.progressNode.isUserInteractionEnabled = false
        self.addSubnode(self.textNode)
        self.textNode.isUserInteractionEnabled = false
        
        self.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:))))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayout(_ size: CGSize) {
        self.validSize = size
        
        let progressSize = CGSize(width: 60.0, height: 60.0)
        let progressFrame = CGRect(origin: CGPoint(x: floor((size.width - progressSize.width) / 2.0), y: floor((size.height - progressSize.height) / 2.0) - 8.0), size: progressSize)
        self.progressNode.frame = progressFrame
        
        let textSize = self.textNode.updateLayout(size)
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: progressFrame.maxY + 15.0), size: textSize)
    }
    
    @objc private func longPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        if case .began = recognizer.state {
            self.serviceAction?()
        }
    }
}
