import Foundation
import UIKit
import ComponentFlow
import ActivityIndicatorComponent
import AccountContext
import AVKit
import MultilineTextComponent
import Display

final class StreamSheetComponent: CombinedComponent {
    let sheetHeight: CGFloat
    let topOffset: CGFloat
    let backgroundColor: UIColor
    let participantsCount: Int
    let bottomPadding: CGFloat
    let isFullyExtended: Bool
    let deviceCornerRadius: CGFloat
    let videoHeight: CGFloat
    
    let isFullscreen: Bool
    let fullscreenTopComponent: AnyComponent<Empty>
    let fullscreenBottomComponent: AnyComponent<Empty>
    
    init(
        topOffset: CGFloat,
        sheetHeight: CGFloat,
        backgroundColor: UIColor,
        bottomPadding: CGFloat,
        participantsCount: Int,
        isFullyExtended: Bool,
        deviceCornerRadius: CGFloat,
        videoHeight: CGFloat,
        isFullscreen: Bool,
        fullscreenTopComponent: AnyComponent<Empty>,
        fullscreenBottomComponent: AnyComponent<Empty>
    ) {
        self.topOffset = topOffset
        self.sheetHeight = sheetHeight
        self.backgroundColor = backgroundColor
        self.bottomPadding = bottomPadding
        self.participantsCount = participantsCount
        self.isFullyExtended = isFullyExtended
        self.deviceCornerRadius = deviceCornerRadius
        self.videoHeight = videoHeight
        
        self.isFullscreen = isFullscreen
        self.fullscreenTopComponent = fullscreenTopComponent
        self.fullscreenBottomComponent = fullscreenBottomComponent
    }
    
    static func ==(lhs: StreamSheetComponent, rhs: StreamSheetComponent) -> Bool {
        if lhs.topOffset != rhs.topOffset {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.sheetHeight != rhs.sheetHeight {
            return false
        }
        if !lhs.backgroundColor.isEqual(rhs.backgroundColor) {
            return false
        }
        if lhs.bottomPadding != rhs.bottomPadding {
            return false
        }
        if lhs.participantsCount != rhs.participantsCount {
            return false
        }
        if lhs.isFullyExtended != rhs.isFullyExtended {
            return false
        }
        if lhs.videoHeight != rhs.videoHeight {
            return false
        }
        
        if lhs.isFullscreen != rhs.isFullscreen {
            return false
        }
        
        if lhs.fullscreenTopComponent != rhs.fullscreenTopComponent {
            return false
        }
        
        if lhs.fullscreenBottomComponent != rhs.fullscreenBottomComponent {
            return false
        }
        
        return true
    }
    
    final class View: UIView {
        var overlayComponentsFrames = [CGRect]()
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            for subframe in overlayComponentsFrames {
                if subframe.contains(point) { return true }
            }
            return false
        }
        
        func update(component: StreamSheetComponent, availableSize: CGSize, state: State, transition: Transition) -> CGSize {
            return availableSize
        }
        
        override func draw(_ rect: CGRect) {
            super.draw(rect)
            // Debug interactive area
//            guard let context = UIGraphicsGetCurrentContext() else { return }
//            context.setFillColor(UIColor.red.withAlphaComponent(0.3).cgColor)
//            overlayComponentsFrames.forEach { frame in
//                context.addRect(frame)
//                context.fillPath()
//            }
        }
    }
    
    func makeView() -> View {
        View()
    }
    
    public final class State: ComponentState {
        override init() {
            super.init()
        }
    }
    
    public func makeState() -> State {
        return State()
    }
    
    private weak var state: State?
    
    static var body: Body {
        let background = Child(SheetBackgroundComponent.self)
        let viewerCounter = Child(ParticipantsComponent.self)
        
        return { context in
            let size = context.availableSize
            
            let topOffset = context.component.topOffset
            let backgroundExtraOffset: CGFloat
            if #available(iOS 16.0, *) {
                // In iOS 16 context.view does not inherit safeAreaInsets, quick fix:
                let safeAreaTopInView = context.view.window.flatMap { $0.convert(CGPoint(x: 0, y: $0.safeAreaInsets.top), to: context.view).y } ?? 0
                backgroundExtraOffset = context.component.isFullyExtended ? -safeAreaTopInView : 0
            } else {
                backgroundExtraOffset = context.component.isFullyExtended ? -context.view.safeAreaInsets.top : 0
            }
            
            let background = background.update(
                component: SheetBackgroundComponent(
                    color: context.component.backgroundColor,
                    radius: context.component.isFullyExtended ? context.component.deviceCornerRadius : 10.0,
                    offset: backgroundExtraOffset
                ),
                availableSize: CGSize(width: size.width, height: context.component.sheetHeight),
                transition: context.transition
            )
            
            let viewerCounter = viewerCounter.update(
                component: ParticipantsComponent(count: context.component.participantsCount, fontSize: 44.0),
                availableSize: CGSize(width: context.availableSize.width, height: 70),
                transition: context.transition
            )
            
            let isFullscreen = context.component.isFullscreen
            
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: topOffset + context.component.sheetHeight / 2))
            )
            
            (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames = []
            context.view.backgroundColor = .clear
            
            let videoHeight = context.component.videoHeight
            let sheetHeight = context.component.sheetHeight
            let animatedParticipantsVisible = !isFullscreen
            
            context.add(viewerCounter
                .position(CGPoint(x: context.availableSize.width / 2, y: topOffset + 50.0 + videoHeight + (sheetHeight - 69.0 - videoHeight - 50.0 - context.component.bottomPadding) / 2 - 10.0))
                .opacity(animatedParticipantsVisible ? 1 : 0)
            )
            
            return size
        }
    }
}

final class SheetBackgroundComponent: Component {
    private let color: UIColor
    private let radius: CGFloat
    private let offset: CGFloat
    
    class View: UIView {
        private let backgroundView = UIView()
        
        func update(availableSize: CGSize, color: UIColor, cornerRadius: CGFloat, offset: CGFloat, transition: Transition) {
            if backgroundView.superview == nil {
                self.addSubview(backgroundView)
            }
            
            let extraBottomForReleaseAnimation: CGFloat = 500
            
            if backgroundView.backgroundColor != color && backgroundView.backgroundColor != nil {
                if transition.animation.isImmediate {
                    UIView.animate(withDuration: 0.4) { [self] in
                        backgroundView.backgroundColor = color
                        backgroundView.frame = .init(origin: .init(x: 0, y: offset), size: .init(width: availableSize.width, height: availableSize.height + extraBottomForReleaseAnimation))
                    }
                    
                    let anim = CABasicAnimation(keyPath: "cornerRadius")
                    anim.fromValue = backgroundView.layer.cornerRadius
                    backgroundView.layer.cornerRadius = cornerRadius
                    anim.toValue = cornerRadius
                    anim.duration = 0.4
                    backgroundView.layer.add(anim, forKey: "cornerRadius")
                } else {
                    transition.setBackgroundColor(view: backgroundView, color: color)
                    transition.setFrame(view: backgroundView, frame: CGRect(origin: .init(x: 0, y: offset), size: .init(width: availableSize.width, height: availableSize.height + extraBottomForReleaseAnimation)))
                    transition.setCornerRadius(layer: backgroundView.layer, cornerRadius: cornerRadius)
                }
            } else {
                backgroundView.backgroundColor = color
                backgroundView.frame = .init(origin: .init(x: 0, y: offset), size: .init(width: availableSize.width, height: availableSize.height + extraBottomForReleaseAnimation))
                backgroundView.layer.cornerRadius = cornerRadius
            }
            backgroundView.isUserInteractionEnabled = false
            backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            backgroundView.clipsToBounds = true
            backgroundView.layer.masksToBounds = true
        }
    }
    
    func makeView() -> View {
        View()
    }
    
    static func ==(lhs: SheetBackgroundComponent, rhs: SheetBackgroundComponent) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.radius != rhs.radius {
            return false
        }
        if lhs.offset != rhs.offset {
            return false
        }
        return true
    }
    
    public init(color: UIColor, radius: CGFloat, offset: CGFloat) {
        self.color = color
        self.radius = radius
        self.offset = offset
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.update(availableSize: availableSize, color: color, cornerRadius: radius, offset: offset, transition: transition)
        return availableSize
    }
}
