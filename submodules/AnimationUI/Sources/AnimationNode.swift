import Foundation
import UIKit
import AsyncDisplayKit
import Lottie
import AppBundle

public final class AnimationNode : ASDisplayNode {
    private let scale: CGFloat
    public var speed: CGFloat = 1.0 {
        didSet {
            if let animationView = animationView() {
                animationView.animationSpeed = speed
            }
        }
    }
    
    private var colorCallbacks: [LOTColorValueCallback] = []
    
    public var didPlay = false
    public var completion: (() -> Void)?
    private var internalCompletion: (() -> Void)?
    
    public var isPlaying: Bool {
        return self.animationView()?.isAnimationPlaying ?? false
    }
    
    private var currentParams: (String?, [String: UIColor]?)?
    
    public init(animation: String? = nil, colors: [String: UIColor]? = nil, scale: CGFloat = 1.0) {
        self.scale = scale
        self.currentParams = (animation, colors)
        
        super.init()
        
        self.setViewBlock({
            if let animation = animation, let url = getAppBundle().url(forResource: animation, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
                let view = LOTAnimationView(model: composition, in: getAppBundle())
                view.animationSpeed = self.speed
                view.backgroundColor = .clear
                view.isOpaque = false
                                
                if let colors = colors {
                    for (key, value) in colors {
                        let colorCallback = LOTColorValueCallback(color: value.cgColor)
                        self.colorCallbacks.append(colorCallback)
                        view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                    }
                }
                
                return view
            } else {
                return LOTAnimationView()
            }
        })
    }
    
    public init(animationData: Data, colors: [String: UIColor]? = nil, scale: CGFloat = 1.0) {
        self.scale = scale
        
        super.init()
        
        self.setViewBlock({
            if let json = try? JSONSerialization.jsonObject(with: animationData, options: []) as? [AnyHashable: Any] {
                let composition = LOTComposition(json: json)
                
                let view = LOTAnimationView(model: composition, in: getAppBundle())
                view.animationSpeed = self.speed
                view.backgroundColor = .clear
                view.isOpaque = false
                                
                if let colors = colors {
                    for (key, value) in colors {
                        let colorCallback = LOTColorValueCallback(color: value.cgColor)
                        self.colorCallbacks.append(colorCallback)
                        view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                    }
                }
                
                return view
            } else {
                return LOTAnimationView()
            }
        })
    }
    
    public func makeCopy(colors: [String: UIColor]? = nil, progress: CGFloat? = nil) -> AnimationNode? {
        guard let (animation, currentColors) = self.currentParams else {
            return nil
        }
        let animationNode = AnimationNode(animation: animation, colors: colors ?? currentColors, scale: 1.0)
        animationNode.animationView()?.play(fromProgress: progress ?? (self.animationView()?.animationProgress ?? 0.0), toProgress: 1.0, withCompletion: { [weak animationNode] _ in
            animationNode?.completion?()
        })
        return animationNode
    }
    
    public func seekToEnd() {
        self.animationView()?.animationProgress = 1.0
    }
    
    public func setAnimation(name: String, colors: [String: UIColor]? = nil) {
        self.currentParams = (name, colors)
        if let url = getAppBundle().url(forResource: name, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
            self.didPlay = false
            self.animationView()?.sceneModel = composition
            
            if let colors = colors {
                for (key, value) in colors {
                    let colorCallback = LOTColorValueCallback(color: value.cgColor)
                    self.colorCallbacks.append(colorCallback)
                    self.animationView()?.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                }
            }
        }
    }
    
    public func setAnimation(data: Data) {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: Any] {
            let composition = LOTComposition(json: json)
            self.didPlay = false
            self.animationView()?.sceneModel = composition
        }
    }
    
    public func setAnimation(json: [AnyHashable: Any]) {
        self.didPlay = false
        self.animationView()?.setAnimation(json: json)
    }
    
    public func animationView() -> LOTAnimationView? {
        return self.view as? LOTAnimationView
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
            animationView.loopAnimation = true
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
        if let animationView = animationView(), let sceneModel = animationView.sceneModel {
            return CGSize(width: sceneModel.compBounds.width * self.scale, height: sceneModel.compBounds.height * self.scale)
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
