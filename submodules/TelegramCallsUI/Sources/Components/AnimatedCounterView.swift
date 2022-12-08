import Foundation
import UIKit
import Display

private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xe4436c)

private let latePurple = UIColor(rgb: 0x974aa9)
private let latePink = UIColor(rgb: 0xf0436c)

public final class AnimatedCountView: UIView {
    let countLabel = AnimatedCountLabel()
//    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    
    private let foregroundView = UIView()
    private let foregroundGradientLayer = CAGradientLayer()
    private let maskingView = UIView()
    private var scaleFactor: CGFloat { 0.7 }
    
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
        countLabel.clipsToBounds = false
        subtitleLabel.textAlignment = .center
        self.clipsToBounds = false
        
        subtitleLabel.textColor = .white
//        self.backgroundColor = UIColor.white.withAlphaComponent(0.1)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.foregroundView.frame = CGRect(origin: CGPoint.zero, size: bounds.size)// .insetBy(dx: -40, dy: -40)
        self.foregroundGradientLayer.frame = CGRect(origin: .zero, size: bounds.size).insetBy(dx: -60, dy: -60)
        self.maskingView.frame = CGRect(origin: .zero, size: bounds.size)
        countLabel.frame = CGRect(origin: .zero, size: bounds.size)
        subtitleLabel.frame = .init(x: bounds.midX - subtitleLabel.intrinsicContentSize.width / 2 - 10, y: subtitleLabel.text == "No viewers" ? bounds.midY - 8 : bounds.height - 12, width: subtitleLabel.intrinsicContentSize.width + 20, height: 20)
    }
    
    func update(countString: String, subtitle: String) {
        self.setupGradientAnimations()
        
        let text: String = countString// presentationStringsFormattedNumber(Int32(count), ",")
 
        //        self.titleNode.attributedText = NSAttributedString(string: "", font: Font.with(size: 23.0, design: .round, weight: .semibold, traits: []), textColor: .white)
        //        let titleSize = self.titleNode.updateLayout(size)
        //        self.titleNode.frame = CGRect(x: floor((size.width - titleSize.width) / 2.0), y: 48.0, width: titleSize.width, height: titleSize.height)
//        if CGFloat(text.count * 40) < bounds.width - 32 {
//            self.countLabel.attributedText = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 60, weight: .semibold)])
//        } else {
//            self.countLabel.attributedText = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 54, weight: .semibold)])
//
        self.countLabel.fontSize = 48
        self.countLabel.attributedText = NSAttributedString(string: text, font: Font.with(size: 48, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: .white)
//        self.countLabel.attributedText = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 60, weight: .semibold)])
//        var timerSize = self.timerNode.updateLayout(CGSize(width: size.width + 100.0, height: size.height))
//        if timerSize.width > size.width - 32.0 {
//            self.timerNode.attributedText = NSAttributedString(string: text, font: Font.with(size: 60.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: .white)
//            timerSize = self.timerNode.updateLayout(CGSize(width: size.width + 100.0, height: size.height))
//        }
        
//        self.timerNode.frame = CGRect(x: floor((size.width - timerSize.width) / 2.0), y: 78.0, width: timerSize.width, height: timerSize.height)
        
        self.subtitleLabel.attributedText = NSAttributedString(string: subtitle, attributes: [.font: UIFont.systemFont(ofSize: 16, weight: .semibold)])
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
    var commaWidthForSpacing: CGFloat { 8 * fontSize / 60 }
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
                    offset -= commaWidthForSpacing * 0.7
                } else {
                    offset -= commaWidthForSpacing / 3
                }
            }
            return offset
        } else {
            var offset = self.chars[0..<index].reduce(0) {
                if $1.attributedText?.string == "," {
                    return $0 + commaWidthForSpacing + interItemSpacing
                }
                return $0 + itemWidth + interItemSpacing
            }
            if self.chars.count > index && self.chars[index].attributedText?.string == "," {
                if index > 0, let prevChar = self.chars[index - 1].attributedText?.string, ["1", "7"].contains(prevChar) {
                    offset -= commaWidthForSpacing * 0.7
                } else {
                    offset -= commaWidthForSpacing / 3
                }
            }
            return offset
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let countWidth = offsetForChar(at: chars.count) /*chars.reduce(0) {
            if $1.attributedText?.string == "," {
                return $0 + commaWidth + interItemSpacing
            }
            return $0 + itemWidth + interItemSpacing
        }*/ - interItemSpacing
        containerView.frame = .init(x: bounds.midX - countWidth / 2 * scaleFactor, y: 0, width: countWidth * scaleFactor, height: bounds.height)
        chars.enumerated().forEach { (index, char) in
            let offset = offsetForChar(at: index)
//            char.frame.size.width = char.attributedText?.string == "," ? commaFrameWidth : itemWidth
            char.frame.origin.x = offset
//            char.frame.origin.x = CGFloat(chars.count - 1 - index) * (40 + interItemSpacing)
            char.frame.origin.y = 0
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
        
        let initialDuration: TimeInterval = min(0.25, maxAnimationDuration / Double(numberOfChanges)) /// 0.25
        
//        let currentWidth = itemWidth * CGFloat(currentChars.count)
//        let newWidth = itemWidth * CGFloat(newChars.count)
        
        let interItemDelay: TimeInterval = 0.08
        var changeIndex = 0
        
        var newLayers = [AnimatedCharLayer]()
        let isInitialSet = currentChars.isEmpty
        for index in 0..<min(newChars.count, currentChars.count) {
            let newCharIndex = newChars.count - 1 - index
            let currCharIndex = currentChars.count - 1 - index
            
            if true || newChars[newCharIndex] != currentChars[currCharIndex] {
//                if newChars[newCharIndex].string != "," {
//                    continue
//                }
                
               let initialDuration = newChars[newCharIndex] != currentChars[currCharIndex] ? initialDuration : 0
                
                if !isInitialSet && newChars[newCharIndex] != currentChars[currCharIndex] {
                    animateOut(for: chars[currCharIndex].layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
                } else {
                    chars[currCharIndex].layer.removeFromSuperlayer()
                }
                let newLayer = AnimatedCharLayer()
                newLayer.attributedText = newChars[newCharIndex]
                let offset = offsetForChar(at: newCharIndex, within: newChars)/* newChars[0..<newCharIndex].reduce(0) {
                    if $1.string == "," {
                        return $0 + commaWidth + interItemSpacing
                    }
                    return $0 + itemWidth + interItemSpacing
                }*/
                newLayer.frame = .init(
                    x: offset/*CGFloat(newCharIndex) * (40 + interItemSpacing)*/,
                    y: 0,
                    width: newChars[newCharIndex].string == "," ? commaFrameWidth : itemWidth,
                    height: itemWidth * 1.8 + (newChars[newCharIndex].string == "," ? 4 : 0)
                )
                // newLayer.frame = .init(x: CGFloat(chars.count - 1 - index) * (40 + interItemSpacing), y: 0, width: itemWidth, height: itemWidth * 1.8)
                containerView.layer.addSublayer(newLayer)
                if !isInitialSet && newChars[newCharIndex] != currentChars[currCharIndex] {
                    newLayer.layer.opacity = 0
                    animateIn(for: newLayer.layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
                    changeIndex += 1
                }
                newLayers.append(newLayer)
//                if newChars[newCharIndex].string == "," {
//                    newLayer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
//                } else {
//                    newLayer.backgroundColor = UIColor.green.withAlphaComponent(0.6).cgColor
//                }
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
//            if newChars[newCharIndex].string != "," {
//                continue
//            }
            let newLayer = AnimatedCharLayer()
            newLayer.attributedText = newChars[newCharIndex]
            
            let offset = offsetForChar(at: newCharIndex, within: newChars)/*newChars[0..<newCharIndex].reduce(0) {
                if $1.string == "," {
                    return $0 + commaWidth + interItemSpacing
                }
                return $0 + itemWidth + interItemSpacing
            }*/
            newLayer.frame = .init(x: offset/*CGFloat(newCharIndex) * (40 + interItemSpacing)*/, y: 0, width: newChars[newCharIndex].string == "," ? commaFrameWidth : itemWidth, height: itemWidth * 1.8 + (newChars[newCharIndex].string == "," ? 4 : 0))
            containerView.layer.addSublayer(newLayer)
            if !isInitialSet {
                animateIn(for: newLayer.layer, duration: initialDuration, beginTime: TimeInterval(changeIndex) * interItemDelay)
            }
            newLayers.append(newLayer)
            changeIndex += 1
        }
        let prevCount = chars.count
        chars = newLayers.reversed()
        
        let countWidth = offsetForChar(at: newChars.count, within: newChars) - interItemSpacing/*newChars.reduce(-interItemSpacing) {
            if $1.string == "," {
                return $0 + commaWidth + interItemSpacing
            }
            return $0 + itemWidth + interItemSpacing
        }*/
        if didBegin && prevCount != chars.count {
            UIView.animate(withDuration: Double(changeIndex) * initialDuration/*, delay: initialDuration * Double(changeIndex)*/) { [self] in
                containerView.frame = .init(x: self.bounds.midX - countWidth / 2, y: 0, width: countWidth, height: self.bounds.height)
                if countWidth * scaleFactor > self.bounds.width {
                    let scale = (self.bounds.width - 32) / (countWidth * scaleFactor)
                    containerView.transform = .init(scaleX: scale, y: scale)
                } else {
                    containerView.transform = .init(scaleX: scaleFactor, y: scaleFactor)
                }
                //            containerView.backgroundColor = .red.withAlphaComponent(0.3)
            }
        } else if countWidth > 0 {
            containerView.frame = .init(x: self.bounds.midX - countWidth / 2 * scaleFactor, y: 0, width: countWidth * scaleFactor, height: self.bounds.height)
            didBegin = true
        }
//        self.backgroundColor = .green.withAlphaComponent(0.2)
        self.clipsToBounds = false
    }
    func animateOut(for layer: CALayer, duration: CFTimeInterval, beginTime: CFTimeInterval) {
//        let animation = CAKeyframeAnimation()
//        animation.keyPath = "opacity"
//        animation.values = [layer.presentation()?.value(forKey: "opacity") ?? 1, 0.0]
//        animation.keyTimes = [0, 1]
//        animation.duration = duration
//        animation.beginTime = CACurrentMediaTime() + beginTime
////        animation.isAdditive = true
//        animation.isRemovedOnCompletion = false
//        animation.fillMode = .backwards
//        layer.opacity = 0
//        layer.add(animation, forKey: "opacity")
//
//
        let beginTimeOffset: CFTimeInterval = 0/*beginTime == .zero ? 0 :*/ // CFTimeInterval(DispatchTime.now().uptimeNanoseconds / 1000000000) /*layer.convertTime(*/// CACurrentMediaTime()//, to: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + beginTime) {
            let currentTime = CFTimeInterval(DispatchTime.now().uptimeNanoseconds / 1000000000)
            let beginTime: CFTimeInterval = 0
            print("[DIFF-out] \(currentTime - beginTimeOffset)")
            let opacityInAnimation = CABasicAnimation(keyPath: "opacity")
            opacityInAnimation.fromValue = 1
            opacityInAnimation.toValue = 0
            opacityInAnimation.fillMode = .forwards
            opacityInAnimation.isRemovedOnCompletion = false
            //        opacityInAnimation.duration = duration
            //        opacityInAnimation.beginTime = beginTimeOffset + beginTime
            //        opacityInAnimation.completion = { _ in
            //            layer.removeFromSuperlayer()
            //        }
            //        layer.add(opacityInAnimation, forKey: "opacity")
            
            //        let timer = Timer.scheduledTimer(withTimeInterval: duration + beginTime, repeats: false) { timer in
            //        DispatchQueue.main.asyncAfter(deadline: .now() + duration + beginTime) {
            //            DispatchQueue.main.async {
            //                layer.backgroundColor = UIColor.red.withAlphaComponent(0.3).cgColor
            //            }
            //            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            //            layer.removeFromSuperlayer()
            //            }
            //            timer.invalidate()
            //         }
            //        RunLoop.current.add(timer, forMode: .common)
            
            let scaleOutAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleOutAnimation.fromValue = 1 // layer.presentation()?.value(forKey: "transform.scale") ?? 1
            scaleOutAnimation.toValue = 0.0
            //        scaleOutAnimation.duration = duration
            //        scaleOutAnimation.beginTime = beginTimeOffset + beginTime
            //        layer.add(scaleOutAnimation, forKey: "scaleout")
            
            let translate = CABasicAnimation(keyPath: "transform.translation")
            translate.fromValue = CGPoint.zero
            translate.toValue = CGPoint(x: 0, y: -layer.bounds.height * 0.3)// -layer.bounds.height + 3.0)
            //        translate.duration = duration
            //        translate.beginTime = beginTimeOffset + beginTime
            //        layer.add(translate, forKey: "translate")
            
            let group = CAAnimationGroup()
            group.animations = [opacityInAnimation, scaleOutAnimation, translate]
            group.duration = duration
            group.beginTime = beginTimeOffset + beginTime
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            group.completion = { _ in
                layer.removeFromSuperlayer()
            }
            //        layer.opacity = 0
            layer.add(group, forKey: "out")
        }
    }
    
    func animateIn(for newLayer: CALayer, duration: CFTimeInterval, beginTime: CFTimeInterval) {
        
        let beginTimeOffset: CFTimeInterval = 0// CFTimeInterval(DispatchTime.now().uptimeNanoseconds / 1000000000)// CACurrentMediaTime()
        DispatchQueue.main.asyncAfter(deadline: .now() + beginTime) { [self] in
            let currentTime = CFTimeInterval(DispatchTime.now().uptimeNanoseconds / 1000000000)
            let beginTime: CFTimeInterval = 0
            print("[DIFF-in] \(currentTime - beginTimeOffset)")
            newLayer.opacity = 0
            //   newLayer.backgroundColor = UIColor.red.cgColor
            
            let opacityInAnimation = CABasicAnimation(keyPath: "opacity")
            opacityInAnimation.fromValue = 0
            opacityInAnimation.toValue = 1
            opacityInAnimation.duration = duration
            opacityInAnimation.beginTime = beginTimeOffset + beginTime
            //        opacityInAnimation.isAdditive = true
            opacityInAnimation.fillMode = .backwards
            newLayer.opacity = 1
            newLayer.add(opacityInAnimation, forKey: "opacity")
            //        newLayer.opacity = 1
            
            let scaleOutAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleOutAnimation.fromValue = 0
            scaleOutAnimation.toValue = 1
            scaleOutAnimation.duration = duration
            scaleOutAnimation.beginTime = beginTimeOffset + beginTime
            //        scaleOutAnimation.isAdditive = true
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
