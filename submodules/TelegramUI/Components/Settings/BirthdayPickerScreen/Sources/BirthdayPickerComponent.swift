import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramCore
import AccountContext
import ComponentFlow

public final class BirthdayPickerComponent: Component {
    public struct Theme: Equatable {
        let backgroundColor: UIColor
        let textColor: UIColor
        let selectionColor: UIColor
        
        public init(presentationTheme: PresentationTheme) {
            self.backgroundColor = presentationTheme.list.itemBlocksBackgroundColor
            self.textColor = presentationTheme.list.itemPrimaryTextColor
            self.selectionColor = presentationTheme.list.itemHighlightedBackgroundColor
        }
    }
        
    public let theme: Theme
    public let strings: PresentationStrings
    public let value: TelegramBirthday
    public let valueUpdated: (TelegramBirthday) -> Void
        
    public init(
        theme: Theme,
        strings: PresentationStrings,
        value: TelegramBirthday,
        valueUpdated: @escaping (TelegramBirthday) -> Void
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
        private var value = TelegramBirthday(day: 1, month: 1, year: nil)
        private var minYear: Int32 = 1900
        private let maxYear: Int32
        
        override init(frame: CGRect) {
            self.maxYear = Int32(self.calendar.component(.year, from: Date()))
            
            super.init(frame: frame)
            
            self.pickerView.delegate = self
            self.pickerView.dataSource = self
            
            self.addSubview(self.pickerView)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: BirthdayPickerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            self.component = component
            self.componentState = state
            
            if let year = component.value.year, year < self.minYear {
                self.minYear = year
            }
            
            self.pickerView.frame = CGRect(origin: .zero, size: availableSize)
            
            if isFirstTime || self.value != component.value {
                self.value = component.value
                self.pickerView.reloadAllComponents()
                
                if let year = component.value.year {
                    self.pickerView.selectRow(Int(year - self.minYear), inComponent: PickerComponent.year.rawValue, animated: false)
                } else {
                    self.pickerView.selectRow(Int(self.maxYear - self.minYear + 1), inComponent: PickerComponent.year.rawValue, animated: false)
                }
                self.pickerView.selectRow(Int(component.value.month) - 1, inComponent: PickerComponent.month.rawValue, animated: false)
                self.pickerView.selectRow(Int(component.value.day) - 1, inComponent: PickerComponent.day.rawValue, animated: false)
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
                let range = Calendar.current.range(of: .day, in: .month, for: Calendar.current.date(from: DateComponents(year: Int(year), month: Int(month)))!)!
                var maxDay = range.upperBound
                if let year = self.value.year, year == self.maxYear {
                    let dateComponents = self.calendar.dateComponents(Set([.month, .day]), from: Date())
                    if dateComponents.month == Int(month), let currentDay = dateComponents.day {
                        maxDay = currentDay + 1
                    }
                }
                return maxDay - range.lowerBound
            case PickerComponent.month.rawValue:
                var maxMonth = 12
                if let year = self.value.year, year == self.maxYear {
                    maxMonth = self.calendar.component(.month, from: Date())
                }
                return maxMonth
            case PickerComponent.year.rawValue:
                return Int(self.maxYear - self.minYear + 2)
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
                    string = "\(self.minYear + Int32(row))"
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
                self.value = self.value.withUpdated(day: Int32(row) + 1)
            case PickerComponent.month.rawValue:
                self.value = self.value.withUpdated(month: Int32(row) + 1)
            case PickerComponent.year.rawValue:
                if row == self.maxYear - self.minYear + 1 {
                    self.value = self.value.withUpdated(year: nil)
                } else {
                    self.value = self.value.withUpdated(year: self.minYear + Int32(row))
                }
            default:
                break
            }
            if [PickerComponent.month.rawValue, PickerComponent.year.rawValue].contains(component) {
                self.pickerView.reloadComponent(PickerComponent.month.rawValue)
                Queue.mainQueue().justDispatch {
                    self.value = self.value.withUpdated(month: Int32(pickerView.selectedRow(inComponent: 1) + 1))
                    self.pickerView.reloadComponent(PickerComponent.day.rawValue)
                    Queue.mainQueue().justDispatch {
                        self.value = self.value.withUpdated(day: Int32(pickerView.selectedRow(inComponent: 0) + 1))
                        self.component?.valueUpdated(self.value)
                    }
                }
            } else {
                self.component?.valueUpdated(self.value)
            }
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

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private extension TelegramBirthday {
    func withUpdated(day: Int32) -> TelegramBirthday {
        return TelegramBirthday(day: day, month: self.month, year: self.year)
    }
    
    func withUpdated(month: Int32) -> TelegramBirthday {
        return TelegramBirthday(day: self.day, month: month, year: self.year)
    }
    
    func withUpdated(year: Int32?) -> TelegramBirthday {
        return TelegramBirthday(day: self.day, month: self.month, year: year)
    }
}
