import UIKit
import SnapKit

public class CustomSegmentControl: UIControl {
    fileprivate var labels = [UILabel]()
    private var thumbView = UIView()
    
    public var items: [String] = ["Item1"] {
        didSet {
            if items.count > 0 {
                setupLabels()
            }
        }
    }
    
    public var selectedIndex: Int = 0 {
        didSet {
            displayNewSelectedIndex()
        }
    }
    
    public var selectedLabelColor: UIColor?
    public var unselectedLabelColor: UIColor?
    public var borderColor: UIColor? {
        didSet {
            layer.borderColor = borderColor?.cgColor
        }
    }
    public var thumbColor: UIColor?
    public var selectedLabelFont: UIFont?
    public var unselectedLabelFont: UIFont?
    public var padding: CGFloat = 2 {
        didSet {
            self.layoutIfNeeded()
        }
    }
    
    public var onSegmentSelected: ((Int) -> ())?
    
    //  MARK: - Lifecycle
    
    public init() {
        super.init(frame: .zero)
        setupView()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)!
        setupView()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        if labels.count > 0 {
            let label = labels[selectedIndex]
            label.textColor = selectedLabelColor
            thumbView.frame = label.frame
            thumbView.backgroundColor = thumbColor
            thumbView.layer.cornerRadius = 4
            displayNewSelectedIndex()
        }
    }
    
    private func setupView() {
        clipsToBounds = true
        layer.cornerRadius = 6
        layer.borderWidth = 1
        
        backgroundColor = UIColor.clear
        setupLabels()
        insertSubview(thumbView, at: 0)
    }
    
    private func setupLabels() {
        for label in labels {
            label.removeFromSuperview()
        }
        
        labels.removeAll(keepingCapacity: true)
        for index in 1...items.count {
            let label = UILabel()
            label.text = items[index - 1]
            label.backgroundColor = .clear
            label.textAlignment = .center
            label.font = index == 1 ? selectedLabelFont : unselectedLabelFont
            label.textColor = index == 1 ? selectedLabelColor : unselectedLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            
            addSubview(label)
            labels.append(label)
        }
        
        addIndividualItemConstraints(labels, mainView: self)
    }
    
    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        var calculatedIndex : Int?
        for (index, item) in labels.enumerated() {
            if item.frame.contains(location) {
                calculatedIndex = index
            }
        }
        
        if calculatedIndex != nil {
            selectedIndex = calculatedIndex!
            sendActions(for: .valueChanged)
            onSegmentSelected?(selectedIndex)
        }
        
        return false
    }
    
    private func displayNewSelectedIndex() {
        for (_, item) in labels.enumerated() {
            item.textColor = unselectedLabelColor
            item.font = unselectedLabelFont
        }
        
        let label = labels[selectedIndex]
        label.textColor = selectedLabelColor
        label.font = selectedLabelFont
        UIView.animate(withDuration: 0.2, delay: 0.0, animations: {
            self.thumbView.frame = label.frame
        }, completion: nil)
    }
    
    private func addIndividualItemConstraints(_ items: [UIView], mainView: UIView) {
        for (index, button) in items.enumerated() {
            button.topAnchor.constraint(equalTo: mainView.topAnchor, constant: padding).isActive = true
            button.bottomAnchor.constraint(equalTo: mainView.bottomAnchor, constant: -padding).isActive = true
            
            if index == 0 {
                button.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: padding).isActive = true
            } else {
                let prevButton: UIView = items[index - 1]
                let firstItem: UIView = items[0]
                
                button.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: padding).isActive = true
                button.widthAnchor.constraint(equalTo: firstItem.widthAnchor).isActive = true
            }
            
            if index == items.count - 1 {
                button.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -padding).isActive = true
            } else {
                let nextButton: UIView = items[index + 1]
                button.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -padding).isActive = true
            }
        }
    }
}
