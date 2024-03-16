import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramCore
import AccountContext
import ComponentFlow

final class PeerInfoScreenBirthdatePickerItem: PeerInfoScreenItem {
    let id: AnyHashable
    let value: BirthdayPickerComponent.BirthDate
    let valueUpdated: (BirthdayPickerComponent.BirthDate) -> Void
    
    init(
        id: AnyHashable,
        value: BirthdayPickerComponent.BirthDate,
        valueUpdated: @escaping (BirthdayPickerComponent.BirthDate) -> Void
    ) {
        self.id = id
        self.value = value
        self.valueUpdated = valueUpdated
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenBirthdatePickerItemNode()
    }
}

private final class PeerInfoScreenBirthdatePickerItemNode: PeerInfoScreenItemNode {
    private let maskNode: ASImageNode
    private let picker = ComponentView<Empty>()
    
    private let bottomSeparatorNode: ASDisplayNode
        
    private var item: PeerInfoScreenBirthdatePickerItem?
    private var presentationData: PresentationData?
    private var theme: PresentationTheme?
    
    override init() {
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
            
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
                        
        super.init()
        
        self.addSubnode(self.bottomSeparatorNode)
        
        self.addSubnode(self.maskNode)
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenBirthdatePickerItem else {
            return 10.0
        }
        
        self.item = item
        self.presentationData = presentationData
        self.theme = presentationData.theme
                
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let height: CGFloat = 226.0
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
     
        let pickerSize = self.picker.update(
            transition: .immediate,
            component: AnyComponent(BirthdayPickerComponent(
                theme: BirthdayPickerComponent.Theme(presentationTheme: presentationData.theme),
                strings: presentationData.strings,
                value: item.value,
                valueUpdated: item.valueUpdated
            )),
            environment: {},
            containerSize: CGSize(width: width - sideInset * 2.0, height: height)
        )
        let pickerFrame = CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: pickerSize)
        if let pickerView = self.picker.view {
            if pickerView.superview == nil {
                self.view.addSubview(pickerView)
            }
            transition.updateFrame(view: pickerView, frame: pickerFrame)
        }
       
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        return height
    }
}

public final class BirthdayPickerComponent: Component {
    public struct Theme: Equatable {
        let backgroundColor: UIColor
        let textColor: UIColor
        let selectionColor: UIColor
        
        init(presentationTheme: PresentationTheme) {
            self.backgroundColor = presentationTheme.list.itemBlocksBackgroundColor
            self.textColor = presentationTheme.list.itemPrimaryTextColor
            self.selectionColor = presentationTheme.list.itemHighlightedBackgroundColor
        }
    }
    
    public struct BirthDate: Equatable {
        let year: Int?
        let month: Int
        let day: Int
        
        init(year: Int?, month: Int, day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }
        
        func withUpdated(year: Int?) -> BirthDate {
            return BirthDate(year: year, month: self.month, day: self.day)
        }
        
        func withUpdated(month: Int) -> BirthDate {
            return BirthDate(year: self.year, month: month, day: self.day)
        }
        
        func withUpdated(day: Int) -> BirthDate {
            return BirthDate(year: self.year, month: self.month, day: day)
        }
    }
    
    public let theme: Theme
    public let strings: PresentationStrings
    public let value: BirthDate
    public let valueUpdated: (BirthDate) -> Void
        
    public init(
        theme: Theme,
        strings: PresentationStrings,
        value: BirthDate,
        valueUpdated: @escaping (BirthDate) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.valueUpdated = valueUpdated
    }
    
    public static func ==(lhs: BirthdayPickerComponent, rhs: BirthdayPickerComponent) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    public final class View: UIView, UIPickerViewDelegate, UIPickerViewDataSource {
        private var component: BirthdayPickerComponent?
        private weak var componentState: EmptyComponentState?
        
        private let pickerView = UIPickerView()
        
        enum PickerComponent: Int {
            case day = 0
            case month = 1
            case year = 2
        }
        
        private let calendar = Calendar(identifier: .gregorian)
        private var value = BirthdayPickerComponent.BirthDate(year: nil, month: 1, day: 1)
        private let minYear = 1900
        private let maxYear: Int
        
        override init(frame: CGRect) {
            self.maxYear = self.calendar.component(.year, from: Date())
            
            super.init(frame: frame)
            
            self.pickerView.delegate = self
            self.pickerView.dataSource = self
            
            self.addSubview(self.pickerView)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: BirthdayPickerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            self.component = component
            self.componentState = state
            
            self.pickerView.frame = CGRect(origin: .zero, size: availableSize)
            
            if isFirstTime || self.value != component.value {
                self.value = component.value
                self.pickerView.reloadAllComponents()
                
                if let year = component.value.year {
                    self.pickerView.selectRow(year - self.minYear, inComponent: PickerComponent.year.rawValue, animated: false)
                } else {
                    self.pickerView.selectRow(self.maxYear - self.minYear + 1, inComponent: PickerComponent.year.rawValue, animated: false)
                }
                self.pickerView.selectRow(component.value.month - 1, inComponent: PickerComponent.month.rawValue, animated: false)
                self.pickerView.selectRow(component.value.day - 1, inComponent: PickerComponent.day.rawValue, animated: false)
            }
            
            return availableSize
        }
        
        public func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 3
        }
        
        public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case PickerComponent.day.rawValue:
                let year = self.value.year ?? 2024
                let month = self.value.month
                let range = Calendar.current.range(of: .day, in: .month, for: Calendar.current.date(from: DateComponents(year: year, month: month))!)!
                return range.upperBound - range.lowerBound
            case PickerComponent.month.rawValue:
                return 12
            case PickerComponent.year.rawValue:
                return self.maxYear - self.minYear + 2
            default:
                return 0
            }
        }
        
        public func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
            var string = ""
            switch component {
            case PickerComponent.day.rawValue:
                string = "\(row + 1)"
            case PickerComponent.month.rawValue:
                guard let strings = self.component?.strings else {
                    break
                }
                switch row {
                case 0:
                    string = strings.Month_GenJanuary
                case 1:
                    string = strings.Month_GenFebruary
                case 2:
                    string = strings.Month_GenMarch
                case 3:
                    string = strings.Month_GenApril
                case 4:
                    string = strings.Month_GenMay
                case 5:
                    string = strings.Month_GenJune
                case 6:
                    string = strings.Month_GenJuly
                case 7:
                    string = strings.Month_GenAugust
                case 8:
                    string = strings.Month_GenSeptember
                case 9:
                    string = strings.Month_GenOctober
                case 10:
                    string = strings.Month_GenNovember
                case 11:
                    string = strings.Month_GenDecember
                default:
                    break
                }
            case PickerComponent.year.rawValue:
                if row == self.maxYear - self.minYear + 1 {
                    string = "⎯"
                } else {
                    string = "\(self.minYear + row)"
                }
            default:
                break
            }
            let textColor = self.component?.theme.textColor ?? .black
            return NSAttributedString(string: string, attributes: [NSAttributedString.Key.foregroundColor: textColor])
        }
                
        public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            switch component {
            case PickerComponent.day.rawValue:
                self.value = self.value.withUpdated(day: row + 1)
            case PickerComponent.month.rawValue:
                self.value = self.value.withUpdated(month: row + 1)
            case PickerComponent.year.rawValue:
                if row == self.maxYear - self.minYear + 1 {
                    self.value = self.value.withUpdated(year: nil)
                } else {
                    self.value = self.value.withUpdated(year: self.minYear + row)
                }
            default:
                break
            }
            if [PickerComponent.month.rawValue, PickerComponent.year.rawValue].contains(component) {
                self.pickerView.reloadComponent(PickerComponent.day.rawValue)
            }
            
            self.component?.valueUpdated(self.value)
        }
        
        public func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            switch component {
            case PickerComponent.day.rawValue:
                return 50.0
            case PickerComponent.month.rawValue:
                return 145.0
            case PickerComponent.year.rawValue:
                return 75.0
            default:
                return 0
            }
        }
        
        public func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            return 40.0
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
