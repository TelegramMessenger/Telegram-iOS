import Foundation
import UIKit
import ComponentFlow
import Display

public final class AudioWaveformComponent: Component {
    public let backgroundColor: UIColor
    public let foregroundColor: UIColor
    public let samples: Data
    public let peak: Int32
    
    public init(
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        samples: Data,
        peak: Int32    
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.samples = samples
        self.peak = peak
    }
    
    public static func ==(lhs: AudioWaveformComponent, rhs: AudioWaveformComponent) -> Bool {
        if lhs.backgroundColor !== rhs.backgroundColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.samples != rhs.samples {
            return false
        }
        if lhs.peak != rhs.peak {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: AudioWaveformComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AudioWaveformComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            return CGSize(width: availableSize.width, height: availableSize.height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
