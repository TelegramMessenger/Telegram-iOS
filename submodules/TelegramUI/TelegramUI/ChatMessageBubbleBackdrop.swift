import Foundation
import AsyncDisplayKit
import Display
import Postbox

private let backgroundContentImage = generateImage(CGSize(width: 1.0, height: 1000.0), rotatedContext: { size, context in
    var locations: [CGFloat] = [0.0, 1.0]
    let colors = [UIColor(rgb: 0x018CFE).cgColor, UIColor(rgb: 0x0A51A1).cgColor] as NSArray
    
    let colorSpace = deviceColorSpace
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
    
    context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
})

private let backgroundContentIncomingImage = generateImage(CGSize(width: 1.0, height: 1000.0), rotatedContext: { size, context in
    var locations: [CGFloat] = [0.0, 1.0]
    let colors = [UIColor(rgb: 0x39393C).cgColor, UIColor(rgb: 0x222224).cgColor] as NSArray
    
    let colorSpace = deviceColorSpace
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
    
    context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
})

private let blurredImage = UIImage(contentsOfFile: "/Users/peter/Library/Developer/CoreSimulator/Devices/5D789082-637B-493D-8CD3-32E59577B64D/data/Containers/Shared/AppGroup/AA2C1D1D-BD42-4662-8003-A4DDC118839F/telegram-data/account-8200745692227124259/postbox/media/telegram-cloud-document-1-5033031402610753634")?.precomposed()

final class ChatMessageBubbleBackdrop: ASDisplayNode {
    private let backgroundContent: ASDisplayNode
    
    private var currentType: Bool?
    
    override init() {
        self.backgroundContent = ASDisplayNode()
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.backgroundContent)
    }
    
    func setType(incoming: Bool, theme: ChatPresentationThemeData, mediaBox: MediaBox) {
        if self.currentType != incoming {
            self.currentType = incoming
            
            //self.backgroundContent.contents = blurredImage?.cgImage
            
            self.backgroundContent.contents = incoming ? backgroundContentIncomingImage?.cgImage : backgroundContentImage?.cgImage
        }
    }
    
    func update(rect: CGRect, within containerSize: CGSize) {
        self.backgroundContent.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
    }
}
