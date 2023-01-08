import Foundation
import Display
import UIKit
import ComponentFlow
import TelegramPresentationData
import TelegramStringFormatting

private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xe4436c)

final class ParticipantsComponent: Component {
    private let count: Int
    private let showsSubtitle: Bool
    private let fontSize: CGFloat
    private let gradientColors: [CGColor]
    
    init(count: Int, showsSubtitle: Bool = true, fontSize: CGFloat = 48.0, gradientColors: [CGColor] = [pink.cgColor, purple.cgColor, purple.cgColor]) {
        self.count = count
        self.showsSubtitle = showsSubtitle
        self.fontSize = fontSize
        self.gradientColors = gradientColors
    }
    
    static func == (lhs: ParticipantsComponent, rhs: ParticipantsComponent) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        if lhs.showsSubtitle != rhs.showsSubtitle {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        return true
    }
    
    func makeView() -> View {
        View(frame: .zero)
    }
    
    func update(view: View, availableSize: CGSize, state: ComponentFlow.EmptyComponentState, environment: ComponentFlow.Environment<ComponentFlow.Empty>, transition: ComponentFlow.Transition) -> CGSize {
        view.counter.update(
            countString: self.count > 0 ? presentationStringsFormattedNumber(Int32(count), ",") : "",
            // TODO: localize
            subtitle: self.showsSubtitle ? (self.count > 0 ? /*environment.strings.LiveStream_Watching*/"watching" : /*environment.strings.LiveStream_NoViewers.lowercased()*/"no viewers") : "",
            fontSize: self.fontSize,
            gradientColors: self.gradientColors
        )
        switch transition.animation {
        case let .curve(duration, curve):
            UIView.animate(withDuration: duration, delay: 0, options: curve.containedViewLayoutTransitionCurve.viewAnimationOptions, animations: {
                view.bounds.size = availableSize
                view.counter.frame.size = availableSize
                view.counter.updateFrames(transition: transition)
            })
            
        default:
            view.bounds.size = availableSize
            view.counter.frame.size = availableSize
            view.counter.updateFrames()
        }
        return availableSize
    }
    
    final class View: UIView {
        let counter = AnimatedCountView()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(counter)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
}
