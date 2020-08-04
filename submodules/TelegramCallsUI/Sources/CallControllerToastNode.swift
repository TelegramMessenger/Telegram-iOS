import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit

private let labelFont = Font.regular(17.0)

final class CallControllerToastNode: ASDisplayNode {
    struct Content: Equatable {
        enum Image {
            case cameraOff
        }
        
        var image: Image
        var text: String
        
        init(image: Image, text: String) {
            self.image = image
            self.text = text
        }
    }
    
    let effectView: UIVisualEffectView
    
    override init() {
        self.effectView = UIVisualEffectView()
        self.effectView.effect = UIBlurEffect(style: .light)
        self.effectView.layer.cornerRadius = 16.0
        self.effectView.clipsToBounds = true
        self.effectView.isUserInteractionEnabled = false
        
        super.init()
        
        self.view.addSubview(self.effectView)
    }
}
