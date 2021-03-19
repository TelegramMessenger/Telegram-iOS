import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

final class CameraModeNode: ASDisplayNode {
    enum Mode {
        case photo
        case video
        case scan
    }
    
    override init() {
        super.init()
    }
    
    func update(mode: Mode, transition: ContainedViewLayoutTransition) {
        
    }
}
