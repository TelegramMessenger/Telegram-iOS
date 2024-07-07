import Foundation
import UIKit
import Display
import ComponentFlow

private let labelWidth: CGFloat = 16.0
private let labelHeight: CGFloat = 36.0
private let labelSize = CGSize(width: labelWidth, height: labelHeight)
private let font = Font.with(size: 24.0, design: .round, weight: .semibold, traits: [])

final class BadgeLabelView: UIView {
    private class StackView: UIView {
        var labels: [UILabel] = []
        
        var currentValue: Int32 = 0
        
        var color: UIColor = .white {
            didSet {
                for view in self.labels {
                    view.textColor = self.color
                }
            }
        }
        
        init() {
            super.init(frame: CGRect(origin: .zero, size: labelSize))
             
            var height: CGFloat = -labelHeight
            for i in -1 ..< 10 {
                let label = UILabel()
                if i == -1 {
                    label.text = "9"
                } else {
                    label.text = "\(i)"
                }
                label.textColor = self.color
                label.font = font
                label.textAlignment = .center
                label.frame = CGRect(x: 0, y: height, width: labelWidth, height: labelHeight)
                self.addSubview(label)
                self.labels.append(label)
                
                height += labelHeight
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(value: Int32, isFirst: Bool, isLast: Bool, transition: ComponentTransition) {
            let previousValue = self.currentValue
            self.currentValue = value
                        
            self.labels[1].alpha = isFirst && !isLast ? 0.0 : 1.0
            
            if previousValue == 9 && value < 9 {
                self.bounds = CGRect(
                    origin: CGPoint(
                        x: 0.0,
                        y: -1.0 * labelSize.height
                    ),
                    size: labelSize
                )
            }
            
            let bounds = CGRect(
                origin: CGPoint(
                    x: 0.0,
                    y: CGFloat(value) * labelSize.height
                ),
                size: labelSize
            )
            transition.setBounds(view: self, bounds: bounds)
        }
    }
    
    private var itemViews: [Int: StackView] = [:]
    private var staticLabel = UILabel()
    
    init() {
        super.init(frame: .zero)
        
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var color: UIColor = .white {
        didSet {
            self.staticLabel.textColor = self.color
            for (_, view) in self.itemViews {
                view.color = self.color
            }
        }
    }
    
    func update(value: String, transition: ComponentTransition) -> CGSize {
        if value.contains(" ") {
            for (_, view) in self.itemViews {
                view.isHidden = true
            }
            
            if self.staticLabel.superview == nil {
                self.staticLabel.textColor = self.color
                self.staticLabel.font = font
                
                self.addSubview(self.staticLabel)
            }
            
            self.staticLabel.text = value
            let size = self.staticLabel.sizeThatFits(CGSize(width: 100.0, height: 100.0))
            self.staticLabel.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: labelHeight))
            
            return CGSize(width: ceil(self.staticLabel.bounds.width), height: ceil(self.staticLabel.bounds.height))
        }
        
        let string = value
        let stringArray = Array(string.map { String($0) }.reversed())
        
        let totalWidth = CGFloat(stringArray.count) * labelWidth
        
        var validIds: [Int] = []
        for i in 0 ..< stringArray.count {
            validIds.append(i)
            
            let itemView: StackView
            var itemTransition = transition
            if let current = self.itemViews[i] {
                itemView = current
            } else {
                itemTransition = transition.withAnimation(.none)
                itemView = StackView()
                itemView.color = self.color
                self.itemViews[i] = itemView
                self.addSubview(itemView)
            }
            
            let digit = Int32(stringArray[i]) ?? 0
            itemView.update(value: digit, isFirst: i == stringArray.count - 1, isLast: i == 0, transition: transition)
            
            itemTransition.setFrame(
                view: itemView,
                frame: CGRect(x: totalWidth - labelWidth * CGFloat(i + 1), y: 0.0, width: labelWidth, height: labelHeight)
            )
        }
        
        var removeIds: [Int] = []
        for (id, itemView) in self.itemViews {
            if !validIds.contains(id) {
                removeIds.append(id)
                
                transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                    itemView.removeFromSuperview()
                })
            }
        }
        for id in removeIds {
            self.itemViews.removeValue(forKey: id)
        }
        return CGSize(width: totalWidth, height: labelHeight)
    }
}
