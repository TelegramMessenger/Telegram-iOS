import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext

private let handleWidth: CGFloat = 14.0
private let scrubberHeight: CGFloat = 39.0
private let borderHeight: CGFloat = 1.0 + UIScreenPixel
private let frameWidth: CGFloat = 24.0

final class VideoScrubberComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let duration: Double
    let startPosition: Double
    let endPosition: Double
    
    init(
        context: AccountContext,
        duration: Double,
        startPosition: Double,
        endPosition: Double
    ) {
        self.context = context
        self.duration = duration
        self.startPosition = startPosition
        self.endPosition = endPosition
    }
    
    static func ==(lhs: VideoScrubberComponent, rhs: VideoScrubberComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate {
        private let containerView = UIView()
        private let leftHandleView = UIImageView()
        private let rightHandleView = UIImageView()
        private let borderView = UIImageView()
        private let cursorView = UIImageView()
        
        private var component: VideoScrubberComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveKeyboardGestureRecognizer = true
            
            let handleImage = generateImage(CGSize(width: handleWidth, height: scrubberHeight), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                
                let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width * 2.0, height: size.height)), cornerRadius: 9.0)
                context.addPath(path.cgPath)
                context.fillPath()
                
                context.setBlendMode(.clear)
                let innerPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: handleWidth - 3.0, y: borderHeight), size: CGSize(width: handleWidth, height: size.height - borderHeight * 2.0)), cornerRadius: 2.0)
                context.addPath(innerPath.cgPath)
                context.fillPath()
                
                let holeSize = CGSize(width: 2.0, height: 11.0)
                let holePath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 5.0 - UIScreenPixel, y: (size.height - holeSize.height) / 2.0), size: holeSize), cornerRadius: holeSize.width / 2.0)
                context.addPath(holePath.cgPath)
                context.fillPath()
            })
            
            self.leftHandleView.image = handleImage
            self.rightHandleView.image = handleImage
            self.rightHandleView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
            
            self.borderView.image = generateImage(CGSize(width: 1.0, height: scrubberHeight), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(origin: .zero, size: CGSize(width: size.width, height: borderHeight)))
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - borderHeight), size: CGSize(width: size.width, height: scrubberHeight)))
            })
            
            self.addSubview(self.containerView)
            self.addSubview(self.leftHandleView)
            self.addSubview(self.rightHandleView)
            self.addSubview(self.borderView)
            self.addSubview(self.cursorView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: VideoScrubberComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let scrubberSize = CGSize(width: availableSize.width, height: scrubberHeight)
            let bounds = CGRect(origin: .zero, size: scrubberSize)
            
            transition.setFrame(view: self.containerView, frame: bounds)
            
            let leftHandleFrame = CGRect(origin: .zero, size: CGSize(width: handleWidth, height: scrubberSize.height))
            transition.setFrame(view: self.leftHandleView, frame: leftHandleFrame)
            
            let rightHandleFrame = CGRect(origin: CGPoint(x: scrubberSize.width - handleWidth, y: 0.0), size: CGSize(width: handleWidth, height: scrubberSize.height))
            transition.setFrame(view: self.rightHandleView, frame: rightHandleFrame)
            
            let borderFrame = CGRect(origin: CGPoint(x: leftHandleFrame.maxX, y: 0.0), size: CGSize(width: rightHandleFrame.minX - leftHandleFrame.maxX, height: scrubberSize.height))
            transition.setFrame(view: self.borderView, frame: borderFrame)
            
            return scrubberSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
