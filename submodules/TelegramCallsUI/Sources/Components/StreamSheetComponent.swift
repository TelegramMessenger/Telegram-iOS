import Foundation
import UIKit
import ComponentFlow
import ActivityIndicatorComponent
import AccountContext
import AVKit
import MultilineTextComponent
import Display

final class StreamSheetComponent: CombinedComponent {
//    let color: UIColor
//    let leftItem: AnyComponent<Empty>?
    let topComponent: AnyComponent<Empty>?
//    let viewerCounter: AnyComponent<Empty>?
    let bottomButtonsRow: AnyComponent<Empty>?
    // TODO: sync
    let sheetHeight: CGFloat
    let topOffset: CGFloat
    let backgroundColor: UIColor
    init(
//        color: UIColor,
        topComponent: AnyComponent<Empty>,
        bottomButtonsRow: AnyComponent<Empty>,
        topOffset: CGFloat,
        sheetHeight: CGFloat,
        backgroundColor: UIColor
    ) {
//        self.leftItem = leftItem
        self.topComponent = topComponent
//        self.viewerCounter = AnyComponent(ViewerCountComponent(count: 0))
        self.bottomButtonsRow = bottomButtonsRow
        self.topOffset = topOffset
        self.sheetHeight = sheetHeight
        self.backgroundColor = backgroundColor
    }
    
    static func ==(lhs: StreamSheetComponent, rhs: StreamSheetComponent) -> Bool {
        if lhs.topComponent != rhs.topComponent {
            return false
        }
        if lhs.bottomButtonsRow != rhs.bottomButtonsRow {
            return false
        }
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
        return true
    }
//
    final class View: UIView {
        var overlayComponentsFrames = [CGRect]()
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            for subframe in overlayComponentsFrames {
                if subframe.contains(point) { return true }
            }
            return false
        }
        
        func update(component: StreamSheetComponent, availableSize: CGSize, state: State, transition: Transition) -> CGSize {
            self.backgroundColor = .purple.withAlphaComponent(0.6)
            return availableSize
        }
        
        override func draw(_ rect: CGRect) {
            super.draw(rect)
            
//            guard let context = UIGraphicsGetCurrentContext() else { return }
//            context.setFillColor(UIColor.red.cgColor)
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
//    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
//        view.isUserInteractionEnabled = false
//        return availableSize
//    }
    /*public func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }*/
    
    static var body: Body {
        let background = Child(SheetBackgroundComponent.self)
//        let leftItem = Child(environment: Empty.self)
        let topItem = Child(environment: Empty.self)
//        let viewerCounter = Child(environment: Empty.self)
        let bottomButtonsRow = Child(environment: Empty.self)
//        let bottomButtons = Child(environment: Empty.self)
//        let rightItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
//        let centerItem = Child(environment: Empty.self)
        
        return { context in
            let availableWidth = context.availableSize.width
//            let sideInset: CGFloat = 16.0 + context.component.sideInset
            
            let contentHeight: CGFloat = 44.0
            let size = context.availableSize// CGSize(width: context.availableSize.width, height:44)// context.component.topInset + contentHeight)
            
            let background = background.update(component: SheetBackgroundComponent(color: context.component.backgroundColor), availableSize: CGSize(width: size.width, height: context.component.sheetHeight), transition: context.transition)
            
            let topItem = context.component.topComponent.flatMap { topItemComponent in
                return topItem.update(
                    component: topItemComponent,
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
                    transition: context.transition
                )
            }
            
//            let viewerCounter = context.component.viewerCounter.flatMap { viewerCounterComponent in
//                return viewerCounter.update(
//                    component: viewerCounterComponent,
//                    availableSize: context.availableSize,
//                    transition: context.transition
//                )
//            }
            
            let bottomButtonsRow = context.component.bottomButtonsRow.flatMap { bottomButtonsRowComponent in
                return bottomButtonsRow.update(
                    component: bottomButtonsRowComponent,
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
                    transition: context.transition
                )
            }
            
            let topOffset = context.component.topOffset
            
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: context.component.topOffset + context.component.sheetHeight / 2))
            )
            
            (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames = []
            context.view.backgroundColor = .clear
            if let topItem = topItem {
                context.add(topItem
                    .position(CGPoint(x: topItem.size.width / 2.0, y: topOffset + contentHeight / 2.0))
                )
                (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames.append(.init(x: 0, y: topOffset, width: topItem.size.width, height: topItem.size.height))
            }
            
//            if let viewerCounter = viewerCounter {
//                let videoHeight = availableWidth / 2
//                let topRowHeight: CGFloat = 50
//                context.add(viewerCounter
//                    .position(CGPoint(x: viewerCounter.size.width / 2, y: topRowHeight + videoHeight + 32))
//                )
//            }
            
            if let bottomButtonsRow = bottomButtonsRow {
                context.add(bottomButtonsRow
                    .position(CGPoint(x: bottomButtonsRow.size.width / 2, y: context.component.sheetHeight - 50 / 2 - 16 + topOffset))
                )
                (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames.append(.init(x: 0, y: context.component.sheetHeight - 50 - 16 + topOffset, width: bottomButtonsRow.size.width, height: bottomButtonsRow.size.height))
            }
            /*if let leftItem = leftItem {
                print(leftItem)
                context.add(leftItem
                    .position(CGPoint(x: leftItem.size.width / 2.0, y: contentHeight / 2.0))
                )
                (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames = [
                    .init(x: 0, y: 0, width: leftItem.size.width, height: leftItem.size.height)
                ]
            }*/

            return size
        }
    }
}

import TelegramPresentationData
import TelegramStringFormatting

private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xef436c)

private let latePurple = UIColor(rgb: 0x974aa9)
private let latePink = UIColor(rgb: 0xf0436c)

final class ViewerCountComponent: Component {
    private let count: Int
    
//    private let counterView: VoiceChatTimerNode
    
    static func ==(lhs: ViewerCountComponent, rhs: ViewerCountComponent) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        return true
    }
    
    init(count: Int) {
        self.count = count
    }
    
    public func update(view: UIView, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        
        /*self.foregroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.foregroundGradientLayer.frame = self.foregroundView.bounds
        self.maskView.frame = self.foregroundView.bounds
        
        let text: String = presentationStringsFormattedNumber(participants, groupingSeparator)
        let subtitle = "listening"
        
        self.titleNode.attributedText = NSAttributedString(string: "", font: Font.with(size: 23.0, design: .round, weight: .semibold, traits: []), textColor: .white)
        let titleSize = self.titleNode.updateLayout(size)
        self.titleNode.frame = CGRect(x: floor((size.width - titleSize.width) / 2.0), y: 48.0, width: titleSize.width, height: titleSize.height)
        
        self.timerNode.attributedText = NSAttributedString(string: text, font: Font.with(size: 68.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: .white)
        
        var timerSize = self.timerNode.updateLayout(CGSize(width: size.width + 100.0, height: size.height))
        if timerSize.width > size.width - 32.0 {
            self.timerNode.attributedText = NSAttributedString(string: text, font: Font.with(size: 60.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: .white)
            timerSize = self.timerNode.updateLayout(CGSize(width: size.width + 100.0, height: size.height))
        }
        
        self.timerNode.frame = CGRect(x: floor((size.width - timerSize.width) / 2.0), y: 78.0, width: timerSize.width, height: timerSize.height)
        
        self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.with(size: 21.0, design: .round, weight: .semibold, traits: []), textColor: .white)
        let subtitleSize = self.subtitleNode.updateLayout(size)
        self.subtitleNode.frame = CGRect(x: floor((size.width - subtitleSize.width) / 2.0), y: 164.0, width: subtitleSize.width, height: subtitleSize.height)
        
        self.foregroundView.frame = CGRect(origin: CGPoint(), size: size)
        */
        return availableSize
    }
}

final class SheetBackgroundComponent: Component {
    private let color: UIColor
    
    class View: UIView {
        private let backgroundView = UIView()
        
        func update(availableSize: CGSize, color: UIColor) {
            if backgroundView.superview == nil {
                self.addSubview(backgroundView)
            }
            // To fix release animation
            let extraBottom: CGFloat = 500
            backgroundView.frame = .init(origin: .zero, size: .init(width: availableSize.width, height: availableSize.height + extraBottom))
            backgroundView.backgroundColor = color// .withAlphaComponent(0.4)
            backgroundView.isUserInteractionEnabled = false
            backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            backgroundView.layer.cornerRadius = 16
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
//        if lhs.width != rhs.width {
//            return false
//        }
//        if lhs.height != rhs.height {
//            return false
//        }
        return true
    }
    
    public init(color: UIColor) {
        self.color = color
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.update(availableSize: availableSize, color: color)
        return availableSize
    }
}
