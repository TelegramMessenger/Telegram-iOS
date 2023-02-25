import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import CheckNode
import SolidRoundedButtonComponent
import LegacyComponents

private func stringForCacheSize(strings: PresentationStrings, size: Int32) -> String {
    if size > 100 {
        return strings.Cache_NoLimit
    } else {
        return dataSizeString(Int64(size) * 1024 * 1024 * 1024, formatting: DataSizeStringFormatting(strings: strings, decimalSeparator: "."))
    }
}

private func totalDiskSpace() -> Int64 {
    do {
        let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        return (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value ?? 0
    } catch {
        return 0
    }
}

private let maximumCacheSizeValues: [Int32] = {
    let diskSpace = totalDiskSpace()
    if diskSpace > 100 * 1024 * 1024 * 1024 {
        return [5, 20, 50, Int32.max]
    } else if diskSpace > 50 * 1024 * 1024 * 1024 {
        return [5, 16, 32, Int32.max]
    } else if diskSpace > 24 * 1024 * 1024 * 1024 {
        return [2, 8, 16, Int32.max]
    } else {
        return [1, 4, 8, Int32.max]
    }
}()

final class StorageKeepSizeComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let value: Int32
    let updateValue: (Int32) -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        value: Int32,
        updateValue: @escaping (Int32) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.updateValue = updateValue
    }
    
    static func ==(lhs: StorageKeepSizeComponent, rhs: StorageKeepSizeComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    class View: UIView {
        private let titles: [ComponentView<Empty>]
        private var sliderView: TGPhotoEditorSliderView?
        
        private var component: StorageKeepSizeComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.titles = (0 ..< 4).map { _ in ComponentView<Empty>() }
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.layer.cornerRadius = 10.0
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StorageKeepSizeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            }
            
            let height: CGFloat = 88.0
            
            var titleSizes: [CGSize] = []
            for i in 0 ..< self.titles.count {
                let titleSize = self.titles[i].update(
                    transition: .immediate,
                    component: AnyComponent(Text(text: stringForCacheSize(strings: component.strings, size: maximumCacheSizeValues[i]), font: Font.regular(13.0), color: component.theme.list.itemSecondaryTextColor)),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                titleSizes.append(titleSize)
            }
            
            let delta = (availableSize.width - 18.0 * 2.0) / CGFloat(titleSizes.count - 1)
            for i in 0 ..< titleSizes.count {
                let titleSize = titleSizes[i]
                if let titleView = self.titles[i].view {
                    if titleView.superview == nil {
                        self.addSubview(titleView)
                    }
                    
                    var position: CGFloat = 18.0 + delta * CGFloat(i)
                    if i == titleSizes.count - 1 {
                        position -= titleSize.width
                    } else if i > 0 {
                        position -= titleSize.width / 2.0
                    }
                    transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: position, y: 15.0), size: titleSize))
                }
            }
            
            var sliderFirstTime = false
            let sliderView: TGPhotoEditorSliderView
            if let current = self.sliderView {
                sliderView = current
            } else {
                sliderFirstTime = true
                sliderView = TGPhotoEditorSliderView()
                sliderView.enablePanHandling = true
                sliderView.trackCornerRadius = 2.0
                sliderView.lineSize = 4.0
                sliderView.dotSize = 5.0
                sliderView.minimumValue = 0.0
                sliderView.maximumValue = 3.0
                sliderView.startValue = 0.0
                sliderView.disablesInteractiveTransitionGestureRecognizer = true
                sliderView.positionsCount = 4
                sliderView.useLinesForPositions = true
                sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
                self.sliderView = sliderView
                self.addSubview(sliderView)
            }
            
            if sliderFirstTime || themeUpdated {
                sliderView.backgroundColor = component.theme.list.itemBlocksBackgroundColor
                sliderView.backColor = component.theme.list.itemSwitchColors.frameColor
                sliderView.startColor = component.theme.list.itemSwitchColors.frameColor
                sliderView.trackColor = component.theme.list.itemAccentColor
                sliderView.knobImage = PresentationResourcesItemList.knobImage(component.theme)
            }
            
            transition.setFrame(view: sliderView, frame: CGRect(origin: CGPoint(x: 15.0, y: 37.0), size: CGSize(width: availableSize.width - 15.0 * 2.0, height: 44.0)))
            sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
            
            self.updateSliderView()
            
            return CGSize(width: availableSize.width, height: height)
        }
        
        private func updateSliderView() {
            guard let sliderView = self.sliderView, let component = self.component else {
                return
            }
            sliderView.maximumValue = 3.0
            sliderView.positionsCount = 4
            
            let value = maximumCacheSizeValues.firstIndex(where: { $0 == component.value }) ?? 0
            sliderView.value = CGFloat(value)
        }
        
        @objc private func sliderValueChanged() {
            guard let component = self.component, let sliderView = self.sliderView else {
                return
            }
            
            let position = Int(sliderView.value)
            let value = maximumCacheSizeValues[position]
            component.updateValue(value)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
