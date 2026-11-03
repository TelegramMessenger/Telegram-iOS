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
import LegacyComponents
import SliderComponent

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
        private let slider: ComponentView<Empty>
        //private var sliderView: TGPhotoEditorSliderView?
        
        private var component: StorageKeepSizeComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.titles = (0 ..< 4).map { _ in ComponentView<Empty>() }
            self.slider = ComponentView<Empty>()
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.layer.cornerRadius = 26.0
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StorageKeepSizeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            }
            
            let height: CGFloat = 96.0
            
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
                    transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: position, y: 19.0), size: titleSize))
                }
            }
            
            let sliderSize = self.slider.update(
                transition: transition,
                component: AnyComponent(
                    SliderComponent(
                        content: .discrete(.init(
                            valueCount: 4,
                            value: maximumCacheSizeValues.firstIndex(where: { $0 == component.value }) ?? 0,
                            markPositions: true,
                            valueUpdated: { value in
                                let sizeValue = maximumCacheSizeValues[value]
                                component.updateValue(sizeValue)
                            }
                        )),
                        useNative: true,
                        trackBackgroundColor: component.theme.list.itemSwitchColors.frameColor,
                        trackForegroundColor: component.theme.list.itemAccentColor
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 15.0 * 2.0, height: 44.0)
            )
            if let sliderView = self.slider.view {
                if sliderView.superview == nil {
                    self.addSubview(sliderView)
                }
                transition.setFrame(view: sliderView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - sliderSize.width) / 2.0), y: 41.0), size: sliderSize))
            }
                        
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
