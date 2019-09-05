import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AppBundle

private func generateArrowImage(color: UIColor) -> UIImage? {
    let smallRadius: CGFloat = 5.0
    let largeRadius: CGFloat = 14.0
    return generateImage(CGSize(width: smallRadius + largeRadius, height: smallRadius + largeRadius + 16.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/SettingsArrow"), color: color), let cgImage = image.cgImage {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - image.size.height - 16.0), size: CGSize(width: size.width, height: 16.0)))
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: size.width - image.size.width, y: size.height - image.size.height), size: image.size))
        }
    })
}

final class InstantPageSettingsNode: ASDisplayNode {
    private var settings: InstantPagePresentationSettings
    private var currentThemeType: (InstantPageThemeType, Bool)
    private var theme: InstantPageSettingsItemTheme
    
    private let applySettings: (InstantPagePresentationSettings) -> Void
    private let openInSafari: () -> Void
    
    private var sections: [[InstantPageSettingsItemNode]] = []
    private let sansFamilyNode: InstantPageSettingsFontFamilyNode
    private let serifFamilyNode: InstantPageSettingsFontFamilyNode
    private let themeItemNode: InstantPageSettingsThemeItemNode
    private let autoNightItemNode: InstantPageSettingsSwitchNode
    private let openInItemNode: InstantPageSettingsButtonItemNode
    
    private let arrowNode: ASImageNode
    private let itemContainerNode: ASDisplayNode
    
    init(strings: PresentationStrings, settings: InstantPagePresentationSettings, currentThemeType: (InstantPageThemeType, Bool), applySettings: @escaping (InstantPagePresentationSettings) -> Void, openInSafari: @escaping () -> Void) {
        self.settings = settings
        self.currentThemeType = currentThemeType
        self.theme = InstantPageSettingsItemTheme.themeFor(currentThemeType.0)
        
        self.applySettings = applySettings
        self.openInSafari = openInSafari
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.image = generateArrowImage(color: self.theme.itemBackgroundColor)
        
        self.itemContainerNode = ASDisplayNode()
        self.itemContainerNode.layer.masksToBounds = true
        self.itemContainerNode.layer.cornerRadius = 16.0
        self.itemContainerNode.backgroundColor = self.theme.listBackgroundColor
        
        var updateSerifImpl: ((Bool) -> Void)?
        var updateThemeTypeImpl: ((InstantPageThemeType) -> Void)?
        var updateAutoNightImpl: ((Bool) -> Void)?
        var openInSafariImpl: (() -> Void)?
        
        self.sansFamilyNode = InstantPageSettingsFontFamilyNode(theme: self.theme, title: "San Francisco", family: nil, checked: !settings.forceSerif, tapped: {
            updateSerifImpl?(false)
        })
        self.serifFamilyNode = InstantPageSettingsFontFamilyNode(theme: self.theme, title: "Georgia", family: "Georgia", checked: settings.forceSerif, tapped: {
            updateSerifImpl?(true)
        })
        self.themeItemNode = InstantPageSettingsThemeItemNode(theme: theme, themeType: settings.themeType, update: { value in
            updateThemeTypeImpl?(value)
        })
        self.autoNightItemNode = InstantPageSettingsSwitchNode(theme: theme, title: strings.InstantPage_AutoNightTheme, isOn: settings.autoNightMode, isEnabled: settings.themeType != .dark, toggled: { value in
            updateAutoNightImpl?(value)
        })
        self.openInItemNode = InstantPageSettingsButtonItemNode(theme: theme, title: strings.Web_OpenExternal, tapped: {
            openInSafariImpl?()
        })
        super.init()
        
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.itemContainerNode)
        
        self.sections = [
            [
                InstantPageSettingsBacklightItemNode(theme: self.theme)
            ],
            [
                InstantPageSettingsFontSizeItemNode(theme: self.theme, fontSizeVariant: Int(settings.fontSize.rawValue), updated: { [weak self] value in
                    if let strongSelf = self {
                        strongSelf.updateSettings {
                            let size: InstantPagePresentationFontSize = InstantPagePresentationFontSize(rawValue: Int32(value)) ?? .standard
                            return $0.withUpdatedFontSize(size)
                        }
                    }
                }),
                self.sansFamilyNode,
                self.serifFamilyNode
            ],
            [
                self.themeItemNode,
                self.autoNightItemNode
            ],
            [
                self.openInItemNode
            ]
        ]
        
        for section in self.sections {
            for item in section {
                self.itemContainerNode.addSubnode(item)
            }
        }
        
        updateSerifImpl = { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateSettings {
                    return $0.withUpdatedForceSerif(value)
                }
            }
        }
        
        updateThemeTypeImpl = { [weak self] value in
            if let strongSelf = self {
                let disableAutoNightMode = strongSelf.currentThemeType.1
                strongSelf.updateSettings {
                    if disableAutoNightMode {
                        let currentTime: Int32 = 0
                        return $0.withUpdatedThemeType(value).withUpdatedIgnoreAutoNightModeUntil(currentTime)
                    } else {
                        return $0.withUpdatedThemeType(value)
                    }
                }
            }
        }
        
        updateAutoNightImpl = { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateSettings {
                    return $0.withUpdatedAutoNightMode(value).withUpdatedIgnoreAutoNightModeUntil(0)
                }
            }
        }
        openInSafariImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.openInSafari()
            }
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let fixedWidth: CGFloat = 295.0
        let sectionSpacing: CGFloat = 4.0
        let sideInset: CGFloat = 11.0
        let topInset: CGFloat = layout.insets(options: [.statusBar]).top + 44.0 + 6.0
        
        var contentHeight: CGFloat = 0.0
        var itemSizes: [[CGFloat]] = []
        for sectionIndex in 0 ..< self.sections.count {
            itemSizes.append([])
            if sectionIndex != 0 {
                contentHeight += sectionSpacing
            }
            for itemIndex in 0 ..< self.sections[sectionIndex].count {
                let previousItem: InstantPageSettingsItemNodeStatus
                var previousItemNode: InstantPageSettingsItemNode?
                let nextItem: InstantPageSettingsItemNodeStatus
                var nextItemNode: InstantPageSettingsItemNode?
                if itemIndex == 0 {
                    if sectionIndex == 0 {
                        previousItem = .none
                    } else {
                        previousItem = .otherSection
                    }
                } else {
                    previousItem = .sameSection
                    previousItemNode = self.sections[sectionIndex][itemIndex - 1]
                }
                if itemIndex == self.sections[sectionIndex].count - 1 {
                    if sectionIndex == self.sections.count - 1 {
                        nextItem = .none
                    } else {
                        nextItem = .otherSection
                    }
                } else {
                    nextItem = .sameSection
                    nextItemNode = self.sections[sectionIndex][itemIndex + 1]
                }
                let itemHeight = self.sections[sectionIndex][itemIndex].updateLayout(width: fixedWidth, previousItem: (previousItem, previousItemNode), nextItem: (nextItem, nextItemNode))
                itemSizes[sectionIndex].append(itemHeight)
                contentHeight += itemHeight
            }
        }
        
        if let image = self.arrowNode.image {
            transition.updateFrame(node: self.arrowNode, frame: CGRect(origin: CGPoint(x: layout.size.width - sideInset - image.size.width, y: topInset - image.size.height + 16.0 + 8.0), size: image.size))
        }
        
        transition.updateFrame(node: self.itemContainerNode, frame: CGRect(origin: CGPoint(x: layout.size.width - sideInset - fixedWidth, y: topInset), size: CGSize(width: fixedWidth, height: contentHeight)))
        var nextItemOffset: CGFloat = 0.0
        for sectionIndex in 0 ..< self.sections.count {
            if sectionIndex != 0 {
                nextItemOffset += sectionSpacing
            }
            for itemIndex in 0 ..< self.sections[sectionIndex].count {
                let itemHeight = itemSizes[sectionIndex][itemIndex]
                transition.updateFrame(node: self.sections[sectionIndex][itemIndex], frame: CGRect(origin: CGPoint(x: 0.0, y: nextItemOffset), size: CGSize(width: fixedWidth, height: itemHeight)))
                nextItemOffset += itemHeight
            }
        }
    }
    
    func animateIn() {
        self.layer.allowsGroupOpacity = true
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, completion: { [weak self] _ in
            self?.layer.allowsGroupOpacity = false
        })
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.allowsGroupOpacity = true
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak self] _ in
            self?.layer.allowsGroupOpacity = false
            completion()
        })
    }
    
    private func updateSettings(_ f: (InstantPagePresentationSettings) -> InstantPagePresentationSettings) {
        let updated = f(self.settings)
        if updated != self.settings {
            self.settings = updated
            
            self.applySettings(settings)
        }
    }
    
    func updateSettingsAndCurrentThemeType(settings: InstantPagePresentationSettings, type: (InstantPageThemeType, Bool)) {
        self.currentThemeType = type
        
        self.sansFamilyNode.checked = !self.settings.forceSerif
        self.serifFamilyNode.checked = self.settings.forceSerif
        self.themeItemNode.themeType = self.settings.themeType
        self.autoNightItemNode.isEnabled = self.settings.themeType != .dark
        
        let theme = InstantPageSettingsItemTheme.themeFor(self.currentThemeType.0)
        if theme != self.theme {
            self.theme = theme
            
            if let snapshotView = self.view.snapshotView(afterScreenUpdates: false) {
                self.view.addSubview(snapshotView)
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
            }
            
            self.arrowNode.image = generateArrowImage(color: self.theme.itemBackgroundColor)
            self.itemContainerNode.backgroundColor = self.theme.listBackgroundColor
            for section in self.sections {
                for item in section {
                    item.updateTheme(self.theme)
                }
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.itemContainerNode.frame.contains(point) {
            return super.hitTest(point, with: event)
        } else {
            return nil
        }
    }
}
