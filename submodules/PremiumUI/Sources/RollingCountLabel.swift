import UIKit
import Display

private extension UILabel {
    func textWidth() -> CGFloat {
        return UILabel.textWidth(label: self)
    }
    
    class func textWidth(label: UILabel) -> CGFloat {
        return textWidth(label: label, text: label.text!)
    }
    
    class func textWidth(label: UILabel, text: String) -> CGFloat {
        return textWidth(font: label.font, text: text)
    }
    
    class func textWidth(font: UIFont, text: String) -> CGFloat {
        let myText = text as NSString
        
        let rect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let labelSize = myText.boundingRect(with: rect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(labelSize.width)
    }
}

open class RollingLabel: UILabel {
    private var fullText = ""
        
    private var suffix: String = ""
    open var showSymbol = false
    private var scrollLayers: [CAScrollLayer] = []
    private var scrollLabels: [UILabel] = []
    private let durationOffset = 0.2
    private let textsNotAnimated = [","]
        
    public func setSuffix(suffix: String) {
        self.suffix = suffix
    }
    
    func configure(with string: String, duration: Double = 0.9) {
        self.fullText = string
        
        self.clean()
        self.setupSubviews()
        
        self.text = " "
        self.animate(duration: duration)
    }
    
    private func animate(ascending: Bool = true, duration: Double) {
        self.createAnimations(ascending: ascending, duration: duration)
    }
    
    private func clean() {
        self.text = nil
        self.subviews.forEach { $0.removeFromSuperview() }
        self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        self.scrollLayers.removeAll()
        self.scrollLabels.removeAll()
    }
    
    private func setupSubviews() {
        let stringArray = fullText.map { String($0) }
        var x: CGFloat = 0
        let y: CGFloat = 0
        if self.textAlignment == .center {
            if showSymbol {
                self.text = "\(fullText) \(suffix)"
            } else {
                self.text = fullText
            }
            let w = UILabel.textWidth(font: self.font, text: self.text ?? "")
            self.text = ""
            x = -(w / 2)
        } else if self.textAlignment == .right {
            if showSymbol {
                self.text = "\(fullText) \(suffix) "
            } else {
                self.text = fullText
            }
            let w = UILabel.textWidth(font: self.font, text: self.text ?? "")
            self.text = ""
            x = -w
        }
        
        if showSymbol {
            let wLabel = UILabel()
            wLabel.frame.origin = CGPoint(x: x, y: y)
            wLabel.textColor = textColor
            wLabel.font = font
            wLabel.text = "\(suffix) "
            wLabel.textAlignment = .center
            wLabel.sizeToFit()
            self.addSubview(wLabel)
            x += wLabel.bounds.width
        }
        
        stringArray.enumerated().forEach { index, text in
            let nonDigits = CharacterSet.decimalDigits.inverted
            if text.rangeOfCharacter(from: nonDigits) != nil {
                let label = UILabel()
                label.frame.origin = CGPoint(x: x, y: y - 1.0 - UIScreenPixel)
                label.textColor = textColor
                label.font = font
                label.text = text
                label.textAlignment = .center
                label.sizeToFit()
                self.addSubview(label)
                
                x += label.bounds.width
            } else {
                let label = UILabel()
                label.frame.origin = CGPoint(x: x, y: y)
                label.textColor = textColor
                label.font = font
                label.text = "0"
                label.textAlignment = .center
                label.sizeToFit()
                createScrollLayer(to: label, text: text, index: index)
                
                x += label.bounds.width
            }
        }
    }
    
    private func createScrollLayer(to label: UILabel, text: String, index: Int) {
        let scrollLayer = CAScrollLayer()
        scrollLayer.frame = CGRect(x: label.frame.minX, y: label.frame.minY - 10.0, width: label.frame.width, height: label.frame.height * 3.0)
        scrollLayers.append(scrollLayer)
        self.layer.addSublayer(scrollLayer)
        
        createContentForLayer(scrollLayer: scrollLayer, text: text, index: index)
    }
    
    private func createContentForLayer(scrollLayer: CAScrollLayer, text: String, index: Int) {
        var textsForScroll: [String] = []
        
        let max: Int
        var found = false
        if let val = Int(text), index == 0 {
            max = val
            found = true
        } else {
            max = 9
        }
        
        for i in 0...max {
            let str = String(i)
            textsForScroll.append(str)
        }
        if !found && text != "9" {
            textsForScroll.append(text)
        }
        
        var height: CGFloat = 0.0
        for text in textsForScroll {
            let label = UILabel()
            label.text = text
            label.textColor = textColor
            label.font = font
            label.textAlignment = .center
            label.frame = CGRect(x: 0, y: height, width: scrollLayer.frame.width, height: scrollLayer.frame.height)
            scrollLayer.addSublayer(label.layer)
            scrollLabels.append(label)

            height = label.frame.maxY
        }
    }
    
    private func createAnimations(ascending: Bool, duration: Double) {
        var offset: CFTimeInterval = 0.0
        
        for scrollLayer in scrollLayers {
            let maxY = scrollLayer.sublayers?.last?.frame.origin.y ?? 0.0
            
            let animation = CABasicAnimation(keyPath: "sublayerTransform.translation.y")
            animation.duration = duration + offset
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            let verticalOffset = 20.0
            if ascending {
                animation.fromValue = maxY + verticalOffset
                animation.toValue = 0
            } else {
                animation.fromValue = 0
                animation.toValue = maxY + verticalOffset
            }
            
            scrollLayer.scrollMode = .vertically
            scrollLayer.add(animation, forKey: nil)
            scrollLayer.scroll(to: CGPoint(x: 0, y: maxY + verticalOffset))
            
            offset += self.durationOffset
        }
    }
}
