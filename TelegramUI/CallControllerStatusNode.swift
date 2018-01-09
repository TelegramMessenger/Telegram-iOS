import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

private let compactNameFont = Font.light(28.0)
private let regularNameFont = Font.light(36.0)

private let compactStatusFont = Font.regular(18.0)
private let regularStatusFont = Font.regular(18.0)

enum CallControllerStatusValue: Equatable {
    case text(String)
    case timer((String) -> String, Double)
    
    static func ==(lhs: CallControllerStatusValue, rhs: CallControllerStatusValue) -> Bool {
        switch lhs {
            case let .text(text):
                if case .text(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .timer(_, referenceTime):
                if case .timer(_, referenceTime) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class CallControllerStatusNode: ASDisplayNode {
    private let titleNode: TextNode
    private let statusNode: TextNode
    private let statusMeasureNode: TextNode
    
    var title: String = ""
    var status: CallControllerStatusValue = .text("") {
        didSet {
            if self.status != oldValue {
                self.statusTimer?.invalidate()
                
                if case .timer = self.status {
                    self.statusTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        if let strongSelf = self, let validLayoutWidth = strongSelf.validLayoutWidth {
                            let _ = strongSelf.updateLayout(constrainedWidth: validLayoutWidth, transition: .immediate)
                        }
                    }, queue: Queue.mainQueue())
                    self.statusTimer?.start()
                } else {
                    if let validLayoutWidth = self.validLayoutWidth {
                        let _ = self.updateLayout(constrainedWidth: validLayoutWidth, transition: .immediate)
                    }
                }
            }
        }
    }
    
    private var statusTimer: SwiftSignalKit.Timer?
    private var validLayoutWidth: CGFloat?
    
    override init() {
        self.titleNode = TextNode()
        self.statusNode = TextNode()
        self.statusNode.displaysAsynchronously = false
        self.statusMeasureNode = TextNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
    }
    
    deinit {
        self.statusTimer?.invalidate()
    }
    
    func updateLayout(constrainedWidth: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayoutWidth = constrainedWidth
        
        let nameFont: UIFont
        let statusFont: UIFont
        if constrainedWidth < 330.0 {
            nameFont = compactNameFont
            statusFont = compactStatusFont
        } else {
            nameFont = regularNameFont
            statusFont = regularStatusFont
        }
        
        let statusText: String
        let statusMeasureText: String
        switch self.status {
            case let .text(text):
                statusText = text
                statusMeasureText = text
            case let .timer(format, referenceTime):
                let duration = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
                let durationString: String
                let measureDurationString: String
                if duration > 60 * 60 {
                    durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
                    measureDurationString = "00:00:00"
                } else {
                    durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
                    measureDurationString = "00:00"
                }
                statusText = format(durationString)
                statusMeasureText = format(measureDurationString)
        }
        
        let spacing: CGFloat = 4.0
        let (titleLayout, titleApply) = TextNode.asyncLayout(self.titleNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.title, font: nameFont, textColor: .white), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)))
        let (statusMeasureLayout, statusMeasureApply) = TextNode.asyncLayout(self.statusMeasureNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: statusMeasureText, font: statusFont, textColor: .white), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)))
        let (statusLayout, statusApply) = TextNode.asyncLayout(self.statusNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: statusText, font: statusFont, textColor: .white), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)))
        
        let _ = titleApply()
        let _ = statusApply()
        let _ = statusMeasureApply()
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((constrainedWidth - titleLayout.size.width) / 2.0), y: 0.0), size: titleLayout.size)
        self.statusNode.frame = CGRect(origin: CGPoint(x: floor((constrainedWidth - statusMeasureLayout.size.width) / 2.0), y: titleLayout.size.height + spacing), size: statusLayout.size)
        
        return titleLayout.size.height + spacing + statusLayout.size.height
    }
}
