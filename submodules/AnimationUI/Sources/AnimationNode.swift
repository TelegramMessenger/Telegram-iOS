import Foundation
import UIKit
import AsyncDisplayKit
import Lottie
import AppBundle
import Display

public final class AnimationNode : ASDisplayNode {
    private let scale: CGFloat
    public var speed: CGFloat = 1.0 {
        didSet {
            if let animationView = animationView() {
                animationView.animationSpeed = speed
            }
        }
    }
    
    //private var colorCallbacks: [LOTColorValueCallback] = []
    
    public var didPlay = false
    public var completion: (() -> Void)?
    private var internalCompletion: (() -> Void)?
    
    public var isPlaying: Bool {
        return self.animationView()?.isAnimationPlaying ?? false
    }
    
    private var currentParams: (String?, [String: UIColor]?)?
    
    public init(animation animationName: String? = nil, colors: [String: UIColor]? = nil, scale: CGFloat = 1.0) {
        self.scale = scale
        self.currentParams = (animationName, colors)
        
        super.init()
        
        self.setViewBlock({
            if let animationName = animationName, let url = getAppBundle().url(forResource: animationName, withExtension: "json"), let animation = Animation.filepath(url.path) {
                let view = AnimationView(animation: animation, configuration: LottieConfiguration(renderingEngine: .mainThread, decodingStrategy: .codable))
                view.animationSpeed = self.speed
                view.backgroundColor = .clear
                view.isOpaque = false
                                
                if let colors = colors {
                    for (key, value) in colors {
                        view.setValueProvider(ColorValueProvider(value.lottieColorValue), keypath: AnimationKeypath(keypath: "\(key).Color"))
                        /*let colorCallback = LOTColorValueCallback(color: value.cgColor)
                        self.colorCallbacks.append(colorCallback)
                        view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))*/
                    }
                }
                
                return view
            } else {
                return AnimationView()
            }
        })
    }
    
    public init(animationData: Data, colors: [String: UIColor]? = nil, scale: CGFloat = 1.0) {
        self.scale = scale
        
        super.init()
        
        self.setViewBlock({
            if let json = try? JSONSerialization.jsonObject(with: animationData, options: []) as? [String: Any], let animation = try? Animation(dictionary: json) {
                let view = AnimationView(animation: animation, configuration: LottieConfiguration(renderingEngine: .mainThread, decodingStrategy: .codable))
                view.animationSpeed = self.speed
                view.backgroundColor = .clear
                view.isOpaque = false
                                
                if let colors = colors {
                    for (key, value) in colors {
                        view.setValueProvider(ColorValueProvider(value.lottieColorValue), keypath: AnimationKeypath(keypath: "\(key).Color"))
                        /*let colorCallback = LOTColorValueCallback(color: value.cgColor)
                        self.colorCallbacks.append(colorCallback)
                        view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))*/
                    }
                }
                
                return view
            } else {
                return AnimationView()
            }
        })
    }
    
    public func makeCopy(colors: [String: UIColor]? = nil, progress: CGFloat? = nil) -> AnimationNode? {
        guard let (animation, currentColors) = self.currentParams else {
            return nil
        }
        let animationNode = AnimationNode(animation: animation, colors: colors ?? currentColors, scale: 1.0)
        animationNode.animationView()?.currentProgress = progress ?? (self.animationView()?.currentProgress ?? 0.0)
        animationNode.animationView()?.play(completion: { [weak animationNode] _ in
            animationNode?.completion?()
        })
        return animationNode
    }
    
    public func seekToEnd() {
        self.animationView()?.currentProgress = 1.0
    }
    
    public func setAnimation(name: String, colors: [String: UIColor]? = nil) {
        self.currentParams = (name, colors)
        if let url = getAppBundle().url(forResource: name, withExtension: "json"), let animation = Animation.filepath(url.path) {
            self.didPlay = false
            self.animationView()?.animation = animation
            
            if let colors = colors {
                for (key, value) in colors {
                    self.animationView()?.setValueProvider(ColorValueProvider(value.lottieColorValue), keypath: AnimationKeypath(keypath: "\(key).Color"))
                    /*let colorCallback = LOTColorValueCallback(color: value.cgColor)
                    self.colorCallbacks.append(colorCallback)
                    self.animationView()?.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))*/
                }
            }
        }
    }
    
    public func setAnimation(data: Data) {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            let animation = try? Animation(dictionary: json)
            self.didPlay = false
            self.animationView()?.animation = animation
        }
    }
    
    public func setAnimation(json: [String: Any]) {
        self.didPlay = false
        if let animation = try? Animation(dictionary: json) {
            self.animationView()?.animation = animation
        }
    }
    
    public func animationView() -> AnimationView? {
        return self.view as? AnimationView
    }
    
    public func play() {
        if let animationView = self.animationView(), !animationView.isAnimationPlaying && !self.didPlay {
            self.didPlay = true
            animationView.play { [weak self] _ in
                self?.completion?()
            }
        }
    }
    
    public func playOnce() {
        if let animationView = self.animationView(), !animationView.isAnimationPlaying && !self.didPlay {
            self.didPlay = true
            self.internalCompletion = { [weak self] in
                self?.didPlay = false
            }
            animationView.play { [weak self] _ in
                self?.internalCompletion?()
            }
        }
    }
    
    public func loop() {
        if let animationView = self.animationView() {
            animationView.loopMode = .loop
            animationView.play()
        }
    }
    
    public func reset() {
        if self.didPlay, let animationView = animationView() {
            self.didPlay = false
            animationView.stop()
        }
    }
    
    public func preferredSize() -> CGSize? {
        if let animationView = animationView(), let animation = animationView.animation {
            return CGSize(width: animation.size.width * self.scale, height: animation.size.height * self.scale)
        } else {
            return nil
        }
    }
}

private let colorKeyRegex = try? NSRegularExpression(pattern: "\"k\":\\[[\\d\\.]+\\,[\\d\\.]+\\,[\\d\\.]+\\,[\\d\\.]+\\]")

public func transformedWithColors(data: Data, colors: [(UIColor, UIColor)]) -> Data {
    if var string = String(data: data, encoding: .utf8) {
        let sourceColors: [UIColor] = colors.map { $0.0 }
        let replacementColors: [UIColor] = colors.map { $0.1 }
        
        func colorToString(_ color: UIColor) -> String {
            var r: CGFloat = 0.0
            var g: CGFloat = 0.0
            var b: CGFloat = 0.0
            if color.getRed(&r, green: &g, blue: &b, alpha: nil) {
                return "\"k\":[\(r),\(g),\(b),1]"
            }
            return ""
        }
        
        func match(_ a: Double, _ b: Double, eps: Double) -> Bool {
            return abs(a - b) < eps
        }
        
        var replacements: [(NSTextCheckingResult, String)] = []
        
        if let colorKeyRegex = colorKeyRegex {
            let results = colorKeyRegex.matches(in: string, range: NSRange(string.startIndex..., in: string))
            for result in results.reversed()  {
                if let range = Range(result.range, in: string) {
                    let substring = String(string[range])
                    let color = substring[substring.index(string.startIndex, offsetBy: "\"k\":[".count) ..< substring.index(before: substring.endIndex)]
                    let components = color.split(separator: ",")
                    if components.count == 4, let r = Double(components[0]), let g = Double(components[1]), let b = Double(components[2]), let a = Double(components[3]) {
                        if match(a, 1.0, eps: 0.01) {
                            for i in 0 ..< sourceColors.count {
                                let color = sourceColors[i]
                                var cr: CGFloat = 0.0
                                var cg: CGFloat = 0.0
                                var cb: CGFloat = 0.0
                                if color.getRed(&cr, green: &cg, blue: &cb, alpha: nil) {
                                    if match(r, Double(cr), eps: 0.01) && match(g, Double(cg), eps: 0.01) && match(b, Double(cb), eps: 0.01) {
                                        replacements.append((result, colorToString(replacementColors[i])))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        for (result, text) in replacements {
            if let range = Range(result.range, in: string) {
                string = string.replacingCharacters(in: range, with: text)
            }
        }
        
        return string.data(using: .utf8) ?? data
    } else {
        return data
    }
}
