import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import LegacyComponents

private let autodownloadSizeValues: [Int32] = [
    1 * 1024 * 1024,
    5 * 1024 * 1024,
    10 * 1024 * 1024,
    50 * 1024 * 1024,
    100 * 1024 * 1024,
    300 * 1024 * 1024,
    500 * 1024 * 1024,
    Int32.max
]

private func closestValue(_ v: Int32) -> Int32 {
    for value in autodownloadSizeValues.reversed() {
        if v >= value {
            return value
        }
    }
    return autodownloadSizeValues[0]
}

public class AutodownloadSliderItem: ActionSheetItem {
    public let strings: PresentationStrings
    public let title: String
    public let value: Int32
    public let updated: (Int32) -> Void
    
    public init(strings: PresentationStrings, title: String, value: Int32, updated: @escaping (Int32) -> Void) {
        self.strings = strings
        self.title = title
        self.value = value
        self.updated = updated
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = AutodownloadSliderItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? AutodownloadSliderItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
    }
}

private func generateKnobImage() -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setShadow(offset: CGSize(width: 0.0, height: -1.0), blur: 3.5, color: UIColor(white: 0.0, alpha: 0.25).cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 28.0, height: 28.0)))
    })
}

public class AutodownloadSliderItemNode: ActionSheetItemNode {
    public static let defaultFont: UIFont = Font.regular(20.0)
    public static let detailFont: UIFont = Font.regular(17.0)
    
    private let theme: ActionSheetControllerTheme
    
    private var item: AutodownloadSliderItem?
    
    private var sliderView: TGPhotoEditorSliderView?
    
    private let titleNode: ImmediateTextNode
    private let labelNode: ImmediateTextNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false

        self.labelNode = ImmediateTextNode()
        self.labelNode.maximumNumberOfLines = 1
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false

        super.init(theme: theme)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let sliderView = TGPhotoEditorSliderView()
        sliderView.enablePanHandling = true
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 1.0
        sliderView.lineSize = 2.0
        sliderView.dotSize = 5.0
        sliderView.minimumValue = 0.0
        sliderView.maximumValue = CGFloat(autodownloadSizeValues.count - 1)
        sliderView.startValue = 0.0
        sliderView.positionsCount = autodownloadSizeValues.count
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        if let item = self.item {
            let value: CGFloat
            let index = autodownloadSizeValues.index(of: closestValue(item.value)) ?? 0
            value = CGFloat(index)
            sliderView.value = value
            sliderView.backgroundColor = .clear
            sliderView.backColor = self.theme.controlColor
            sliderView.trackColor = self.theme.controlAccentColor
            sliderView.knobImage = generateKnobImage()
            
            sliderView.frame = CGRect(origin: CGPoint(x: 24.0, y: 40.0), size: CGSize(width: self.bounds.width - 24.0 * 2.0, height: 44.0))
        }
        self.view.addSubview(sliderView)
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.sliderView = sliderView
    }
    
    func setItem(_ item: AutodownloadSliderItem) {
        self.item = item
        
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: AutodownloadSliderItemNode.defaultFont, textColor: self.theme.primaryTextColor)
        self.updateLabel(item.value)
    }
    
    func updateLabel(_ value: Int32) {
        guard let item = self.item else {
            return
        }
        
        var value = value
        if value == Int32.max {
            value = 1536 * 1024 * 1024
        }
        self.labelNode.attributedText = NSAttributedString(string: item.strings.AutoDownloadSettings_UpTo(dataSizeString(Int64(value))).0, font: AutodownloadSliderItemNode.detailFont, textColor: self.theme.secondaryTextColor)
        
        self.setNeedsLayout()
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 96.0)
    }
    
    public override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.sliderView?.frame = CGRect(origin: CGPoint(x: 24.0, y: 40.0), size: CGSize(width: size.width - 24.0 * 2.0, height: 44.0))
        
        let labelSize = self.labelNode.updateLayout(CGSize(width: size.width - 24.0 - 15.0 - 8.0, height: size.height))
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - 24.0 - labelSize.width - 15.0 - 8.0, height: size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 24.0, y: 15.0), size: titleSize)
        self.labelNode.frame = CGRect(origin: CGPoint(x: size.width - 24.0 - labelSize.width, y: 18.0), size: labelSize)
    }
    
    @objc func sliderValueChanged() {
        guard let sliderView = self.sliderView else {
            return
        }
        let index = Int(sliderView.value)
        let value: Int32
        if index >= 0 && index < autodownloadSizeValues.count {
            value = autodownloadSizeValues[index]
        } else {
            value = autodownloadSizeValues[0]
        }
        self.item?.updated(value)
        self.updateLabel(value)
    }
}
