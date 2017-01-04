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

final class NetworkStatusTitleView: UIView {
    private let titleNode: ASTextNode
    private let activityIndicator: UIActivityIndicatorView
    
    var title: NetworkStatusTitle = NetworkStatusTitle(text: "", activity: false) {
        didSet {
            if self.title != oldValue {
                self.titleNode.attributedText = NSAttributedString(string: title.text, font: Font.medium(17.0), textColor: .black)
                if self.title.activity != oldValue.activity {
                    if self.title.activity {
                        self.activityIndicator.isHidden = false
                        self.activityIndicator.startAnimating()
                    } else {
                        self.activityIndicator.isHidden = true
                        self.activityIndicator.stopAnimating()
                    }
                }
                self.setNeedsLayout()
            }
        }
    }
    
    override init(frame: CGRect) {
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        self.activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        
        super.init(frame: frame)
        
        self.addSubnode(self.titleNode)
        self.addSubview(self.activityIndicator)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        var indicatorPadding: CGFloat = 0.0
        let indicatorSize = self.activityIndicator.bounds.size
        
        if !self.activityIndicator.isHidden {
            indicatorPadding = indicatorSize.width + 6.0
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: max(1.0, size.width - indicatorPadding), height: size.height))
        let combinedHeight = titleSize.height
        
        let titleFrame = CGRect(origin: CGPoint(x: indicatorPadding + floor((size.width - titleSize.width - indicatorPadding) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
        
        if !self.activityIndicator.isHidden {
            self.activityIndicator.frame = CGRect(origin: CGPoint(x: titleFrame.minX - indicatorSize.width - 6.0, y: titleFrame.minY + 1.0), size: indicatorSize)
        }
    }
}
