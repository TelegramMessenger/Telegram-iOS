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
    let participantsCount: Int
    let bottomPadding: CGFloat
    
    init(
//        color: UIColor,
        topComponent: AnyComponent<Empty>,
        bottomButtonsRow: AnyComponent<Empty>,
        topOffset: CGFloat,
        sheetHeight: CGFloat,
        backgroundColor: UIColor,
        bottomPadding: CGFloat,
        participantsCount: Int
    ) {
//        self.leftItem = leftItem
        self.topComponent = topComponent
//        self.viewerCounter = AnyComponent(ViewerCountComponent(count: 0))
        self.bottomButtonsRow = bottomButtonsRow
        self.topOffset = topOffset
        self.sheetHeight = sheetHeight
        self.backgroundColor = backgroundColor
        self.bottomPadding = bottomPadding
        self.participantsCount = participantsCount
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
        if lhs.bottomPadding != rhs.bottomPadding {
            return false
        }
        if lhs.participantsCount != rhs.participantsCount {
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
        let viewerCounter = Child(ParticipantsComponent.self)
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
            
            let viewerCounter = viewerCounter.update(
                component: ParticipantsComponent(count: context.component.participantsCount),
                availableSize: CGSize(width: context.availableSize.width, height: 70),
                transition: context.transition
            )
            
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
                    .position(CGPoint(x: topItem.size.width / 2.0, y: topOffset + 32))
                )
                (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames.append(.init(x: 0, y: topOffset, width: topItem.size.width, height: topItem.size.height))
            }
            let videoHeight = (availableWidth - 32) / 16 * 9
            let sheetHeight = context.component.sheetHeight
            let animatedParticipantsVisible = context.component.participantsCount != -1
            if true {
                context.add(viewerCounter
                    .position(CGPoint(x: context.availableSize.width / 2, y: topOffset + 50 + videoHeight + (sheetHeight - 69 - videoHeight - 50 - context.component.bottomPadding) / 2 - 12))
                    .opacity(animatedParticipantsVisible ? 1 : 0)
                )
            }
            
            if let bottomButtonsRow = bottomButtonsRow {
                context.add(bottomButtonsRow
                    .position(CGPoint(x: bottomButtonsRow.size.width / 2, y: context.component.sheetHeight - 50 / 2 + topOffset - context.component.bottomPadding))
                )
                (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames.append(.init(x: 0, y: context.component.sheetHeight - 50 - 20 + topOffset - context.component.bottomPadding, width: bottomButtonsRow.size.width, height: bottomButtonsRow.size.height ))
            }
            
            return size
        }
    }
}

import TelegramPresentationData
import TelegramStringFormatting

private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xe4436c)

private let latePurple = UIColor(rgb: 0x974aa9)
private let latePink = UIColor(rgb: 0xf0436c)

final class SheetBackgroundComponent: Component {
    private let color: UIColor
    
    class View: UIView {
        private let backgroundView = UIView()
        
        func update(availableSize: CGSize, color: UIColor, transition: Transition) {
            if backgroundView.superview == nil {
                self.addSubview(backgroundView)
            }
            // To fix release animation
            let extraBottom: CGFloat = 500
            backgroundView.frame = .init(origin: .zero, size: .init(width: availableSize.width, height: availableSize.height + extraBottom))
            if backgroundView.backgroundColor != color {
                UIView.animate(withDuration: 0.4) { [self] in
                    backgroundView.backgroundColor = color
                }
            } else {
                backgroundView.backgroundColor = color
            }
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
        view.update(availableSize: availableSize, color: color, transition: transition)
        return availableSize
    }
}

final class ParticipantsComponent: Component {
    static func == (lhs: ParticipantsComponent, rhs: ParticipantsComponent) -> Bool {
        lhs.count == rhs.count
    }
    
    func makeView() -> View {
        View(frame: .zero)
    }
    
    func update(view: View, availableSize: CGSize, state: ComponentFlow.EmptyComponentState, environment: ComponentFlow.Environment<ComponentFlow.Empty>, transition: ComponentFlow.Transition) -> CGSize {
        view.counter.update(
            countString: count > 0 ? presentationStringsFormattedNumber(Int32(count), ",") : "",
            subtitle: count > 0 ? "watching" : "no viewers"
        )// environment.strings.LiveStream_NoViewers)
        return availableSize
    }
    
    private let count: Int
    
    init(count: Int) {
        self.count = count
    }
    
    final class View: UIView {
        let counter = AnimatedCountView()// VoiceChatTimerNode.init(strings: .init(), dateTimeFormat: .init())
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(counter)
            counter.clipsToBounds = false
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            self.counter.frame = self.bounds
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
}

public final class AnimatedCountView: UIView {
    let countLabel = AnimatedCountLabel()
//    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    
    private let foregroundView = UIView()
    private let foregroundGradientLayer = CAGradientLayer()
    private let maskingView = UIView()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        
        self.foregroundGradientLayer.type = .radial
        self.foregroundGradientLayer.colors = [pink.cgColor, purple.cgColor, purple.cgColor]
        self.foregroundGradientLayer.locations = [0.0, 0.85, 1.0]
        self.foregroundGradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
        self.foregroundGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        
        self.foregroundView.mask = self.maskingView
        self.foregroundView.layer.addSublayer(self.foregroundGradientLayer)
        
        self.addSubview(self.foregroundView)
//        self.addSubview(self.titleLabel)
        self.addSubview(self.subtitleLabel)
        
        self.maskingView.addSubview(countLabel)
        
        subtitleLabel.textAlignment = .center
//        self.backgroundColor = UIColor.white.withAlphaComponent(0.1)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.foregroundView.frame = CGRect(origin: CGPoint.zero, size: bounds.size)// .insetBy(dx: -40, dy: -40)
        self.foregroundGradientLayer.frame = CGRect(origin: .zero, size: bounds.size).insetBy(dx: -60, dy: -60)
        self.maskingView.frame = CGRect(origin: .zero, size: bounds.size)
        countLabel.frame = CGRect(origin: .zero, size: bounds.size)
        subtitleLabel.frame = .init(x: bounds.midX - subtitleLabel.intrinsicContentSize.width / 2 - 10, y: subtitleLabel.text == "No viewers" ? bounds.midY - 10 : bounds.height - 6, width: subtitleLabel.intrinsicContentSize.width + 20, height: 20)
    }
    
    func update(countString: String, subtitle: String) {
        self.setupGradientAnimations()
        
        let text: String = countString// presentationStringsFormattedNumber(Int32(count), ",")
 
        //        self.titleNode.attributedText = NSAttributedString(string: "", font: Font.with(size: 23.0, design: .round, weight: .semibold, traits: []), textColor: .white)
        //        let titleSize = self.titleNode.updateLayout(size)
        //        self.titleNode.frame = CGRect(x: floor((size.width - titleSize.width) / 2.0), y: 48.0, width: titleSize.width, height: titleSize.height)
        if CGFloat(text.count * 40) < bounds.width - 32 {
            self.countLabel.attributedText = NSAttributedString(string: text, font: Font.with(size: 60.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: .white)
        } else {
            self.countLabel.attributedText = NSAttributedString(string: text, font: Font.with(size: 54.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: .white)
        }
//        var timerSize = self.timerNode.updateLayout(CGSize(width: size.width + 100.0, height: size.height))
//        if timerSize.width > size.width - 32.0 {
//            self.timerNode.attributedText = NSAttributedString(string: text, font: Font.with(size: 60.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: .white)
//            timerSize = self.timerNode.updateLayout(CGSize(width: size.width + 100.0, height: size.height))
//        }
        
//        self.timerNode.frame = CGRect(x: floor((size.width - timerSize.width) / 2.0), y: 78.0, width: timerSize.width, height: timerSize.height)
        
        self.subtitleLabel.attributedText = NSAttributedString(string: subtitle, font: Font.with(size: 16.0, design: .round, weight: .semibold, traits: []), textColor: .white)
        self.subtitleLabel.isHidden = subtitle.isEmpty
//        let subtitleSize = self.subtitleNode.updateLayout(size)
//        self.subtitleNode.frame = CGRect(x: floor((size.width - subtitleSize.width) / 2.0), y: 164.0, width: subtitleSize.width, height: subtitleSize.height)
        
//        self.foregroundView.frame = CGRect(origin: CGPoint(), size: size)
        // self.setNeedsLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupGradientAnimations() {
        if let _ = self.foregroundGradientLayer.animation(forKey: "movement") {
        } else {
            let previousValue = self.foregroundGradientLayer.startPoint
            let newValue = CGPoint(x: CGFloat.random(in: 0.65 ..< 0.85), y: CGFloat.random(in: 0.1 ..< 0.45))
            self.foregroundGradientLayer.startPoint = newValue
            
            CATransaction.begin()
            
            let animation = CABasicAnimation(keyPath: "startPoint")
            animation.duration = Double.random(in: 0.8 ..< 1.4)
            animation.fromValue = previousValue
            animation.toValue = newValue
            
            CATransaction.setCompletionBlock { [weak self] in
//                if let isCurrentlyInHierarchy = self?.isCurrentlyInHierarchy, isCurrentlyInHierarchy {
                    self?.setupGradientAnimations()
//                }
            }
            self.foregroundGradientLayer.add(animation, forKey: "movement")
            CATransaction.commit()
        }
    }
}

class AnimatedCharLayer: CATextLayer {
    var text: String? {
        get {
            self.string as? String ?? (self.string as? NSAttributedString)?.string
        }
        set {
            self.string = newValue
        }
    }
    var attributedText: NSAttributedString? {
        get {
            self.string as? NSAttributedString //?? (self.string as? String).map { NSAttributed.init
        }
        set {
            self.string = newValue
        }
    }
    
    var layer: CALayer { self }
    
    override init() {
        super.init()
        
        self.contentsScale = UIScreen.main.scale
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
        self.contentsScale = UIScreen.main.scale
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AnimatedCountLabel: UILabel {
    override var text: String? {
        get {
            chars.reduce("") { $0 + ($1.text ?? "") }
        }
        set {
            update(with: newValue ?? "")
        }
    }
    
    override var attributedText: NSAttributedString? {
        get {
            let string = NSMutableAttributedString()
            for char in chars {
                string.append(char.attributedText ?? NSAttributedString())
            }
            return string
        }
        set {
            udpateAttributed(with: newValue ?? NSAttributedString())
        }
    }
    
    private var chars = [AnimatedCharLayer]()
    private let containerView = UIView()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        
        addSubview(containerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    var itemWidth: CGFloat { 36 }
    var commaWidth: CGFloat { 8 }
    override func layoutSubviews() {
        super.layoutSubviews()
        let interItemSpacing: CGFloat = 0
        let countWidth = chars.reduce(0) {
            if $1.attributedText?.string == "," {
                return $0 + commaWidth
            }
            return $0 + itemWidth + interItemSpacing
        } - interItemSpacing
        
        containerView.frame = .init(x: bounds.midX - countWidth / 2, y: 0, width: countWidth, height: bounds.height)
        chars.enumerated().forEach { (index, char) in
            let offset = chars[0..<index].reduce(0) {
                if $1.attributedText?.string == "," {
                    return $0 + commaWidth
                }
                return $0 + itemWidth + interItemSpacing
            }
            char.frame.origin.x = offset
//            char.frame.origin.x = CGFloat(chars.count - 1 - index) * (40 + interItemSpacing)
            char.frame.origin.y = 0
        }
    }
    /// Unused
    func update(with newString: String) {
        /*let itemWidth: CGFloat = 40
        let initialDuration: TimeInterval = 0.3
        let newChars = Array(newString).map { String($0) }
        let currentChars = chars.map { $0.text ?? "X" }
        
//        let currentWidth = itemWidth * CGFloat(currentChars.count)
        let newWidth = itemWidth * CGFloat(newChars.count)
        
        let interItemDelay: TimeInterval = 0.15
        var changeIndex = 0
        
        var newLayers = [AnimatedCharLayer]()
        
        for index in 0..<min(newChars.count, currentChars.count) {
            let newCharIndex = newChars.count - 1 - index
            let currCharIndex = currentChars.count - 1 - index
            
            if true || newChars[newCharIndex] != currentChars[currCharIndex] {
                animateOut(for: chars[currCharIndex].layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
                
                let newLayer = AnimatedCharLayer()
                newLayer.text = newChars[newCharIndex]
                newLayer.frame = .init(x: newWidth - CGFloat(index + 1) * itemWidth, y: 100, width: itemWidth, height: 36)
                containerView.layer.addSublayer(newLayer)
                animateIn(for: newLayer.layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
                newLayers.append(newLayer)
                changeIndex += 1
            } else {
                newLayers.append(chars[currCharIndex])
            }
        }
        
        for index in min(newChars.count, currentChars.count)..<currentChars.count {
            let currCharIndex = currentChars.count - 1 - index
            // remove unused
            animateOut(for: chars[currCharIndex].layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
            changeIndex += 1
        }
        
        for index in min(newChars.count, currentChars.count)..<newChars.count {
            let newCharIndex = newChars.count - 1 - index
            
            let newLayer = AnimatedCharLayer()
            newLayer.text = newChars[newCharIndex]
            newLayer.frame = .init(x: newWidth - CGFloat(index + 1) * itemWidth, y: 100, width: itemWidth, height: 36)
            containerView.layer.addSublayer(newLayer)
            animateIn(for: newLayer.layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
            newLayers.append(newLayer)
            changeIndex += 1
        }
        chars = newLayers*/
    }
    
    func udpateAttributed(with newString: NSAttributedString) {
        let interItemSpacing: CGFloat = 0
        
        let separatedStrings = Array(newString.string).map { String($0) }
        var range = NSRange(location: 0, length: 0)
        var newChars = [NSAttributedString]()
        for string in separatedStrings {
            range.length = string.count
            let attributedString = newString.attributedSubstring(from: range)
            newChars.append(attributedString)
            range.location += range.length
        }
        
        let currentChars = chars.map { $0.attributedText ?? .init() }
        
        let maxAnimationDuration: TimeInterval = 0.5
        var numberOfChanges = abs(newChars.count - currentChars.count)
        for index in 0..<min(newChars.count, currentChars.count) {
            let newCharIndex = newChars.count - 1 - index
            let currCharIndex = currentChars.count - 1 - index
            if newChars[newCharIndex] != currentChars[currCharIndex] {
                numberOfChanges += 1
            }
        }
        
        let initialDuration: TimeInterval = min(0.25, maxAnimationDuration / Double(numberOfChanges)) /// 0.25
        
//        let currentWidth = itemWidth * CGFloat(currentChars.count)
//        let newWidth = itemWidth * CGFloat(newChars.count)
        
        let interItemDelay: TimeInterval = 0.08
        var changeIndex = 0
        
        var newLayers = [AnimatedCharLayer]()
        
        for index in 0..<min(newChars.count, currentChars.count) {
            let newCharIndex = newChars.count - 1 - index
            let currCharIndex = currentChars.count - 1 - index
            
            if true || newChars[newCharIndex] != currentChars[currCharIndex] {
               let initialDuration = newChars[newCharIndex] != currentChars[currCharIndex] ? initialDuration : 0
                
                if newChars[newCharIndex] != currentChars[currCharIndex] {
                    animateOut(for: chars[currCharIndex].layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
                } else {
                    chars[currCharIndex].layer.removeFromSuperlayer()
                }
                let newLayer = AnimatedCharLayer()
                newLayer.attributedText = newChars[newCharIndex]
                let offset = newChars[0..<newCharIndex].reduce(0) {
                    if $1.string == "," {
                        return $0 + commaWidth
                    }
                    return $0 + itemWidth + interItemSpacing
                }
                newLayer.frame = .init(x: offset/*CGFloat(newCharIndex) * (40 + interItemSpacing)*/, y: 0, width: itemWidth, height: itemWidth * 1.8)
                // newLayer.frame = .init(x: CGFloat(chars.count - 1 - index) * (40 + interItemSpacing), y: 0, width: itemWidth, height: itemWidth * 1.8)
                containerView.layer.addSublayer(newLayer)
                if newChars[newCharIndex] != currentChars[currCharIndex] {
                    newLayer.layer.opacity = 0
                    animateIn(for: newLayer.layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
                }
                newLayers.append(newLayer)
                changeIndex += 1
            } else {
                newLayers.append(chars[currCharIndex])
            }
        }
        
        for index in min(newChars.count, currentChars.count)..<currentChars.count {
            let currCharIndex = currentChars.count - 1 - index
            // remove unused
            animateOut(for: chars[currCharIndex].layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
            changeIndex += 1
        }
        
        for index in min(newChars.count, currentChars.count)..<newChars.count {
            let newCharIndex = newChars.count - 1 - index
            
            let newLayer = AnimatedCharLayer()
            newLayer.attributedText = newChars[newCharIndex]
            
            let offset = newChars[0..<newCharIndex].reduce(0) {
                if $1.string == "," {
                    return $0 + commaWidth
                }
                return $0 + itemWidth + interItemSpacing
            }
            newLayer.frame = .init(x: offset/*CGFloat(newCharIndex) * (40 + interItemSpacing)*/, y: 0, width: itemWidth, height: itemWidth * 1.8)
            containerView.layer.addSublayer(newLayer)
            animateIn(for: newLayer.layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
            newLayers.append(newLayer)
            changeIndex += 1
        }
        let prevCount = chars.count
        chars = newLayers.reversed()
        
        let countWidth = newChars.reduce(-interItemSpacing) {
            if $1.string == "," {
                return $0 + commaWidth
            }
            return $0 + itemWidth + interItemSpacing
        }
        if didBegin && prevCount != chars.count {
            UIView.animate(withDuration: Double(changeIndex) * initialDuration/*, delay: initialDuration * Double(changeIndex)*/) { [self] in
                containerView.frame = .init(x: self.bounds.midX - countWidth / 2, y: 0, width: countWidth, height: self.bounds.height)
                //            containerView.backgroundColor = .red.withAlphaComponent(0.3)
            }
        } else {
            containerView.frame = .init(x: self.bounds.midX - countWidth / 2, y: 0, width: countWidth, height: self.bounds.height)
            didBegin = true
        }
//        self.backgroundColor = .green.withAlphaComponent(0.2)
        self.clipsToBounds = false
    }
    var didBegin = false
    func animateOut(for layer: CALayer, duration: CFTimeInterval, beginTime: CFTimeInterval) {
        let animation = CAKeyframeAnimation()
        animation.keyPath = "opacity"
        animation.values = [layer.presentation()?.value(forKey: "opacity") ?? 1, 0.0]
        animation.keyTimes = [0, 1]
        animation.duration = duration
        animation.beginTime = CACurrentMediaTime() + beginTime
//        animation.isAdditive = true
        animation.isRemovedOnCompletion = false
        animation.fillMode = .backwards
        layer.opacity = 0
        layer.add(animation, forKey: "opacity")
//
//
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + beginTime) {
            layer.removeFromSuperlayer()
        }
        let scaleOutAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleOutAnimation.fromValue = layer.presentation()?.value(forKey: "transform.scale") ?? 1
        scaleOutAnimation.toValue = 0.1
        scaleOutAnimation.duration = duration
        scaleOutAnimation.beginTime = CACurrentMediaTime() + beginTime
        layer.add(scaleOutAnimation, forKey: "scaleout")
        
        let translate = CABasicAnimation(keyPath: "transform.translation")
        translate.fromValue = CGPoint.zero
        translate.toValue = CGPoint(x: 0, y: -layer.bounds.height * 0.3)// -layer.bounds.height + 3.0)
        translate.duration = duration
        translate.beginTime = CACurrentMediaTime() + beginTime
        layer.add(translate, forKey: "translate")
    }
    
    func animateIn(for newLayer: CALayer, duration: CFTimeInterval, beginTime: CFTimeInterval) {
        newLayer.opacity = 0
     //   newLayer.backgroundColor = UIColor.red.cgColor
        
        let opacityInAnimation = CABasicAnimation(keyPath: "opacity")
        opacityInAnimation.fromValue = 0
        opacityInAnimation.toValue = 1
        opacityInAnimation.duration = duration
        opacityInAnimation.beginTime = CACurrentMediaTime() + beginTime
//        opacityInAnimation.isAdditive = true
        opacityInAnimation.fillMode = .backwards
        newLayer.opacity = 1
        newLayer.add(opacityInAnimation, forKey: "opacity")
//        newLayer.opacity = 1
        
        let scaleOutAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleOutAnimation.fromValue = 0
        scaleOutAnimation.toValue = 1
        scaleOutAnimation.duration = duration
        scaleOutAnimation.beginTime = CACurrentMediaTime() + beginTime
//        scaleOutAnimation.isAdditive = true
        newLayer.add(scaleOutAnimation, forKey: "scalein")
        
        let animation = CAKeyframeAnimation()
        animation.keyPath = "position.y"
        animation.values = [18, -6, 0]
        animation.keyTimes = [0, 0.64, 1]
        animation.timingFunction = CAMediaTimingFunction.init(name: .easeInEaseOut)
        animation.duration = duration / 0.64
        animation.beginTime = CACurrentMediaTime() + beginTime
        animation.isAdditive = true
        newLayer.add(animation, forKey: "pos")
    }
}
