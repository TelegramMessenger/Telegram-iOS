import Foundation
import UIKit
import Display
import ComponentFlow

private let purple = UIColor(rgb: 0xdf44b8)
private let pink = UIColor(rgb: 0x3851eb)

public final class AnimatedCountView: UIView {
    let countLabel = AnimatedCountLabel()
    let subtitleLabel = UILabel()
    
    private let foregroundView = UIView()
    private let foregroundGradientLayer = CAGradientLayer()
    private let maskingView = UIView()
    private var scaleFactor: CGFloat { 0.7 }
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        
        self.foregroundGradientLayer.type = .radial
        self.foregroundGradientLayer.locations = [0.0, 0.85, 1.0]
        self.foregroundGradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
        self.foregroundGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        
        self.foregroundView.mask = self.maskingView
        self.foregroundView.layer.addSublayer(self.foregroundGradientLayer)
        
        self.addSubview(self.foregroundView)
        self.addSubview(self.subtitleLabel)
        
        self.maskingView.addSubview(countLabel)
        countLabel.clipsToBounds = false
        subtitleLabel.textAlignment = .center
        self.clipsToBounds = false
        
        subtitleLabel.textColor = .white
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.updateFrames()
    }
    
    func updateFrames(transition: ComponentFlow.Transition? = nil) {
        let subtitleHeight: CGFloat = subtitleLabel.intrinsicContentSize.height
        let subtitleFrame = CGRect(x: bounds.midX - subtitleLabel.intrinsicContentSize.width / 2 - 10, y: self.countLabel.attributedText?.length == 0 ? bounds.midY - subtitleHeight / 2 : bounds.height - subtitleHeight, width: subtitleLabel.intrinsicContentSize.width + 20, height: subtitleHeight)
        if let transition {
            transition.setFrame(view: self.foregroundView, frame: CGRect(origin: CGPoint.zero, size: bounds.size))
            transition.setFrame(layer: self.foregroundGradientLayer, frame: CGRect(origin: .zero, size: bounds.size).insetBy(dx: -60, dy: -60))
            transition.setFrame(view: self.maskingView, frame: CGRect(origin: CGPoint.zero, size: bounds.size))
            transition.setFrame(view: self.countLabel, frame: CGRect(origin: CGPoint.zero, size: bounds.size))
            transition.setFrame(view: self.subtitleLabel, frame: subtitleFrame)
        } else {
            self.foregroundView.frame = CGRect(origin: CGPoint.zero, size: bounds.size)// .insetBy(dx: -40, dy: -40)
            self.foregroundGradientLayer.frame = CGRect(origin: .zero, size: bounds.size).insetBy(dx: -60, dy: -60)
            self.maskingView.frame = CGRect(origin: .zero, size: bounds.size)
            
            countLabel.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: bounds.height))
            subtitleLabel.frame = subtitleFrame
        }
            
    }
    
    func update(countString: String, subtitle: String, fontSize: CGFloat = 48.0, gradientColors: [CGColor] = [pink.cgColor, purple.cgColor, purple.cgColor]) {
        self.setupGradientAnimations()
        
        let backgroundGradientColors: [CGColor]
        if gradientColors.count == 1 {
            backgroundGradientColors = [gradientColors[0], gradientColors[0]]
        } else {
            backgroundGradientColors = gradientColors
        }
        self.foregroundGradientLayer.colors = backgroundGradientColors
        
        let text: String = countString
        self.countLabel.fontSize = fontSize
        self.countLabel.attributedText = NSAttributedString(string: text, font: Font.with(size: fontSize, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: .white)
        
        self.subtitleLabel.attributedText = NSAttributedString(string: subtitle, attributes: [.font: UIFont.systemFont(ofSize: max(floor((fontSize + 4.0) / 3.0), 12.0), weight: .semibold)])
        self.subtitleLabel.isHidden = subtitle.isEmpty
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
                self?.setupGradientAnimations()
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
            self.string as? NSAttributedString
        }
        set {
            self.string = newValue
        }
    }
    
    var layer: CALayer { self }
    
    override init() {
        super.init()
        self.contentsScale = UIScreen.main.scale
        self.masksToBounds = false
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
        self.contentsScale = UIScreen.main.scale
        self.masksToBounds = false
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
//            update(with: newValue ?? "")
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
    
    var itemWidth: CGFloat { 36 * fontSize / 60 }
    var commaWidthForSpacing: CGFloat { 12 * fontSize / 60 }
    var commaFrameWidth: CGFloat { 36 * fontSize / 60 }
    var interItemSpacing: CGFloat { 0 * fontSize / 60 }
    var didBegin = false
    var fontSize: CGFloat = 60
    var scaleFactor: CGFloat { 1 }
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        containerView.clipsToBounds = false
        addSubview(containerView)
        self.clipsToBounds = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func offsetForChar(at index: Int, within characters: [NSAttributedString]? = nil) -> CGFloat {
        if let characters {
            var offset =  characters[0..<index].reduce(0) {
                if $1.string == "," {
                    return $0 + commaWidthForSpacing + interItemSpacing
                }
                return $0 + itemWidth + interItemSpacing
            }
            if characters.count > index && characters[index].string == "," {
                if index > 0, ["1", "7"].contains(characters[index - 1].string) {
                    offset -= commaWidthForSpacing * 0.5
                } else {
                    offset -= commaWidthForSpacing / 6// 3
                }
            }
            return offset
        } else {
            return offsetForChar(at: index, within: self.chars.compactMap(\.attributedText))
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let countWidth = offsetForChar(at: chars.count) - interItemSpacing
        containerView.frame = .init(x: bounds.midX - countWidth / 2 * scaleFactor, y: 0, width: countWidth * scaleFactor, height: bounds.height)
        chars.enumerated().forEach { (index, char) in
            let offset = offsetForChar(at: index)
            char.frame.origin.x = offset
            char.frame.origin.y = 0
            char.frame.size.height = containerView.bounds.height
        }
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
        
        let maxAnimationDuration: TimeInterval = 1.2
        var numberOfChanges = abs(newChars.count - currentChars.count)
        for index in 0..<min(newChars.count, currentChars.count) {
            let newCharIndex = newChars.count - 1 - index
            let currCharIndex = currentChars.count - 1 - index
            if newChars[newCharIndex] != currentChars[currCharIndex] {
                numberOfChanges += 1
            }
        }
        
        let initialDuration: TimeInterval = min(0.25, maxAnimationDuration / Double(numberOfChanges))
        
        let interItemDelay: TimeInterval = 0.08
        var changeIndex = 0
        
        var newLayers = [AnimatedCharLayer]()
        let isInitialSet = currentChars.isEmpty
        for index in 0..<min(newChars.count, currentChars.count) {
            let newCharIndex = newChars.count - 1 - index
            let currCharIndex = currentChars.count - 1 - index
            
            if newChars[newCharIndex] != currentChars[currCharIndex] {
               let initialDuration = newChars[newCharIndex] != currentChars[currCharIndex] ? initialDuration : 0
                
                if !isInitialSet && newChars[newCharIndex] != currentChars[currCharIndex] {
                    animateOut(for: chars[currCharIndex].layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
                } else {
                    chars[currCharIndex].layer.removeFromSuperlayer()
                }
                let newLayer = AnimatedCharLayer()
                newLayer.attributedText = newChars[newCharIndex]
                let offset = offsetForChar(at: newCharIndex, within: newChars)
                newLayer.frame = .init(
                    x: offset,
                    y: 0,
                    width: newChars[newCharIndex].string == "," ? commaFrameWidth : itemWidth,
                    height: itemWidth * 1.8 + (newChars[newCharIndex].string == "," ? 4 : 0)
                )
                
                containerView.layer.addSublayer(newLayer)
                if !isInitialSet && newChars[newCharIndex] != currentChars[currCharIndex] {
                    newLayer.layer.opacity = 0
                    animateIn(for: newLayer.layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
                    changeIndex += 1
                }
                newLayers.append(newLayer)
            } else {
                newLayers.append(chars[currCharIndex])
                let offset = offsetForChar(at: newCharIndex, within: newChars)
                chars[currCharIndex].frame = .init(
                    x: offset,
                    y: 0,
                    width: newChars[newCharIndex].string == "," ? commaFrameWidth : itemWidth,
                    height: itemWidth * 1.8 + (newChars[newCharIndex].string == "," ? 4 : 0)
                )
            }
        }
        
        for index in min(newChars.count, currentChars.count)..<currentChars.count {
            let currCharIndex = currentChars.count - 1 - index
            animateOut(for: chars[currCharIndex].layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
            changeIndex += 1
        }
        
        for index in min(newChars.count, currentChars.count)..<newChars.count {
           
            let newCharIndex = newChars.count - 1 - index
            let newLayer = AnimatedCharLayer()
            newLayer.attributedText = newChars[newCharIndex]
            
            let offset = offsetForChar(at: newCharIndex, within: newChars)
            newLayer.frame = .init(x: offset, y: 0, width: newChars[newCharIndex].string == "," ? commaFrameWidth : itemWidth, height: itemWidth * 1.8 + (newChars[newCharIndex].string == "," ? 4 : 0))
            containerView.layer.addSublayer(newLayer)
            if !isInitialSet {
                animateIn(for: newLayer.layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
            }
            newLayers.append(newLayer)
            changeIndex += 1
        }
        let prevCount = chars.count
        chars = newLayers.reversed()
        
        let countWidth = offsetForChar(at: newChars.count, within: newChars) - interItemSpacing
        if didBegin && prevCount != chars.count {
            UIView.animate(withDuration: Double(changeIndex) * initialDuration) { [self] in
                containerView.frame = .init(x: self.bounds.midX - countWidth / 2, y: 0, width: countWidth, height: self.bounds.height)
                if countWidth * scaleFactor > self.bounds.width {
                    let scale = (self.bounds.width - 32) / (countWidth * scaleFactor)
                    containerView.transform = .init(scaleX: scale, y: scale)
                } else {
                    containerView.transform = .init(scaleX: scaleFactor, y: scaleFactor)
                }
            }
        } else if countWidth > 0 {
            containerView.frame = .init(x: self.bounds.midX - countWidth / 2 * scaleFactor, y: 0, width: countWidth * scaleFactor, height: self.bounds.height)
            didBegin = true
        }
        self.clipsToBounds = false
    }
    func animateOut(for layer: CALayer, duration: CFTimeInterval, beginTime: CFTimeInterval) {
        let beginTimeOffset: CFTimeInterval = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + beginTime) {
            let beginTime: CFTimeInterval = 0
            
            let opacityInAnimation = CABasicAnimation(keyPath: "opacity")
            opacityInAnimation.fromValue = 1
            opacityInAnimation.toValue = 0
            opacityInAnimation.fillMode = .forwards
            opacityInAnimation.isRemovedOnCompletion = false
            
            let scaleOutAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleOutAnimation.fromValue = 1
            scaleOutAnimation.toValue = 0.0
            
            let translate = CABasicAnimation(keyPath: "transform.translation")
            translate.fromValue = CGPoint.zero
            translate.toValue = CGPoint(x: 0, y: -layer.bounds.height * 0.3)
            
            let group = CAAnimationGroup()
            group.animations = [opacityInAnimation, scaleOutAnimation, translate]
            group.duration = duration
            group.beginTime = beginTimeOffset + beginTime
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            group.completion = { _ in
                layer.removeFromSuperlayer()
            }
            layer.add(group, forKey: "out")
        }
    }
    
    func animateIn(for newLayer: CALayer, duration: CFTimeInterval, beginTime: CFTimeInterval) {
        
        let beginTimeOffset: CFTimeInterval = 0 // CACurrentMediaTime()
        DispatchQueue.main.asyncAfter(deadline: .now() + beginTime) { [self] in
            let beginTime: CFTimeInterval = 0
            newLayer.opacity = 0
            
            let opacityInAnimation = CABasicAnimation(keyPath: "opacity")
            opacityInAnimation.fromValue = 0
            opacityInAnimation.toValue = 1
            opacityInAnimation.duration = duration
            opacityInAnimation.beginTime = beginTimeOffset + beginTime
            opacityInAnimation.fillMode = .backwards
            newLayer.opacity = 1
            newLayer.add(opacityInAnimation, forKey: "opacity")
            
            let scaleOutAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleOutAnimation.fromValue = 0
            scaleOutAnimation.toValue = 1
            scaleOutAnimation.duration = duration
            scaleOutAnimation.beginTime = beginTimeOffset + beginTime
            newLayer.add(scaleOutAnimation, forKey: "scalein")
            
            let animation = CAKeyframeAnimation()
            animation.keyPath = "position.y"
            animation.values = [20 * fontSize / 60, -6 * fontSize / 60, 0]
            animation.keyTimes = [0, 0.64, 1]
            animation.timingFunction = CAMediaTimingFunction.init(name: .easeInEaseOut)
            animation.duration = duration / 0.64
            animation.beginTime = beginTimeOffset + beginTime
            animation.isAdditive = true
            newLayer.add(animation, forKey: "pos")
        }
    }
}
