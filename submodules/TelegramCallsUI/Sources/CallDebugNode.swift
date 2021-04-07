import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

private func attributedStringForDebugInfo(_ info: String, version: String) -> NSAttributedString {
    guard !info.isEmpty else {
        return NSAttributedString(string: "")
    }
    
    var string = info
    string = "libtgvoip v\(version)\n" + string
    string = string.replacingOccurrences(of: "Remote endpoints: \n", with: "")
    string = string.replacingOccurrences(of: "Jitter ", with: "\nJitter ")
    string = string.replacingOccurrences(of: "Key fingerprint:\n", with: "Key fingerprint: ")
    
    let attributedString = NSMutableAttributedString(string: string, attributes: [NSAttributedString.Key.font: Font.monospace(10), NSAttributedString.Key.foregroundColor: UIColor.white])
    
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.alignment = .center
    titleStyle.lineSpacing = 7.0
    
    let style = NSMutableParagraphStyle()
    style.lineHeightMultiple = 1.15
    
    let secondaryColor = UIColor(rgb: 0xa6a9a8)
    let activeColor = UIColor(rgb: 0xa0d875)
    
    let titleAttributes = [NSAttributedString.Key.font: Font.semiboldMonospace(15), NSAttributedString.Key.paragraphStyle: titleStyle]
    let nameAttributes = [NSAttributedString.Key.font: Font.semiboldMonospace(10), NSAttributedString.Key.foregroundColor: secondaryColor]
    let styleAttributes = [NSAttributedString.Key.paragraphStyle: style]
    let typeAttributes = [NSAttributedString.Key.foregroundColor: secondaryColor]
    let activeAttributes = [NSAttributedString.Key.font: Font.semiboldMonospace(10), NSAttributedString.Key.foregroundColor: activeColor]
    
    let range = string.startIndex ..< string.endIndex
    string.enumerateSubstrings(in: range, options: NSString.EnumerationOptions.byLines) { (line, range, _, _) in
        guard let line = line else {
            return
        }
        if range.lowerBound == string.startIndex {
            attributedString.addAttributes(titleAttributes, range: NSRange(range, in: string))
        }
        else {
            if let semicolonRange = line.range(of: ":") {
                if let bracketRange = line.range(of: "[") {
                    if let _ = line.range(of: "IN_USE") {
                        attributedString.addAttributes(activeAttributes, range: NSRange(range, in: string))
                    } else {
                        let offset = line.distance(from: line.startIndex, to: bracketRange.lowerBound)
                        let distance = line.distance(from: line.startIndex, to: line.endIndex)
                        attributedString.addAttributes(typeAttributes, range: NSRange(string.index(range.lowerBound, offsetBy: offset) ..< string.index(range.lowerBound, offsetBy: distance), in: string))
                    }
                } else {
                    attributedString.addAttributes(styleAttributes, range: NSRange(range, in: string))
                    
                    let offset = line.distance(from: line.startIndex, to: semicolonRange.upperBound)
                    attributedString.addAttributes(nameAttributes, range: NSRange(range.lowerBound ..< string.index(range.lowerBound, offsetBy: offset), in: string))
                }
            }
        }
    }
    
    return attributedString
}

final class CallDebugNode: ASDisplayNode {
    private let disposable = MetaDisposable()
    
    private let dimNode: ASDisplayNode
    private let textNode: ASTextNode
    
    private let timestamp = CACurrentMediaTime()
    
    public var dismiss: (() -> Void)?
    
    init(signal: Signal<(String, String), NoError>) {
        self.dimNode = ASDisplayNode()
        self.dimNode.isLayerBacked = true
        self.dimNode.backgroundColor = UIColor(rgb: 0x26282c, alpha: 0.95)
        self.dimNode.isUserInteractionEnabled = false
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.textNode)
        
        self.disposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] (version, info) in
            self?.update(info, version: version)
        }))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    private func update(_ info: String, version: String) {
        self.textNode.attributedText = attributedStringForDebugInfo(info, version: version)
        self.setNeedsLayout()
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if CACurrentMediaTime() - self.timestamp > 1.0 {
            self.dismiss?()
        }
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        self.dimNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height))
        
        let textSize = textNode.measure(CGSize(width: size.width - 20.0, height: size.height))
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
    }
}
