import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramCore

private let lineImage: UIImage = {
    let radius: CGFloat = 4.0
    return generateImage(CGSize(width: radius, height: radius * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    })!.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(radius)).withRenderingMode(.alwaysTemplate)
}()

public final class MessageQuoteView: UIView {
    public struct Params {
        let presentationData: ChatPresentationData
        let authorName: String?
        let text: String
        let entities: [MessageTextEntity]
        
        public init(
            presentationData: ChatPresentationData,
            authorName: String?,
            text: String,
            entities: [MessageTextEntity]
        ) {
            self.presentationData = presentationData
            self.authorName = authorName
            self.text = text
            self.entities = entities
        }
    }
    
    private let lineView: UIImageView
    
    override private init(frame: CGRect) {
        self.lineView = UIImageView()
        self.lineView.image = lineImage
        
        super.init(frame: frame)
        
        self.addSubview(self.lineView)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public static func asyncLayout(_ view: MessageQuoteView?) -> (Params) -> (CGSize, (CGSize) -> MessageQuoteView) {
        return { params in
            var minSize = CGSize()
            
            minSize.height = 100.0
            
            return (minSize, { size in
                let view = view ?? MessageQuoteView(frame: CGRect())
                
                view.lineView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: lineImage.size.width, height: size.height))
                
                return view
            })
        }
    }
}
