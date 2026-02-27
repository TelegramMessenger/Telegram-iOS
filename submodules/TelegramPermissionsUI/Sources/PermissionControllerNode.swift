import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import TelegramPermissions
import AppBundle

public struct PermissionControllerCustomIcon: Equatable {
    let light: UIImage?
    let dark: UIImage?
    
    public init(light: UIImage?, dark: UIImage?) {
        self.light = light
        self.dark = dark
    }
}

public enum PermissionControllerContent: Equatable {
    case permission(PermissionState?)
    case custom(icon: PermissionContentIcon, title: String, subtitle: String?, text: String, buttonTitle: String, secondaryButtonTitle: String?, footerText: String?)
}

private struct PermissionControllerDataState: Equatable {
    var state: PermissionControllerContent?
}

private struct PermissionControllerLayoutState: Equatable {
    let layout: ContainerViewLayout
    let navigationHeight: CGFloat
}

private struct PermissionControllerInnerState: Equatable {
    var layout: PermissionControllerLayoutState?
    var data: PermissionControllerDataState
}

private struct PermissionControllerState: Equatable {
    var layout: PermissionControllerLayoutState
    var data: PermissionControllerDataState
}

extension PermissionControllerState {
    init?(_ state: PermissionControllerInnerState) {
        guard let layout = state.layout else {
            return nil
        }
        self.init(layout: layout, data: state.data)
    }
}

private func localizedString(for key: String, strings: PresentationStrings, fallback: String = "") -> String {
    if let string = strings.primaryComponent.dict[key] {
        return string
    } else if let string = strings.secondaryComponent?.dict[key] {
        return string
    } else {
        return fallback
    }
}

final class PermissionControllerNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let splitTest: PermissionUISplitTest?
    
    private var innerState: PermissionControllerInnerState
    
    private var contentNode: PermissionContentNode?
    
    var allow: (() -> Void)?
    var openPrivacyPolicy: (() -> Void)?
    var dismiss: (() -> Void)?
    
    init(context: AccountContext, splitTest: PermissionUISplitTest?) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.splitTest = splitTest
        self.innerState = PermissionControllerInnerState(layout: nil, data: PermissionControllerDataState(state: nil))
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.updatePresentationData(self.presentationData)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.contentNode?.updatePresentationData(self.presentationData)
    }
    
    func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    public func setState(_ state: PermissionControllerContent, transition: ContainedViewLayoutTransition) {
        self.updateState({ currentState -> PermissionControllerInnerState in
            return PermissionControllerInnerState(layout: currentState.layout, data: PermissionControllerDataState(state: state))
        }, transition: transition)
    }
    
    private func updateState(_ f: (PermissionControllerInnerState) -> PermissionControllerInnerState, transition: ContainedViewLayoutTransition) {
        let updatedState = f(self.innerState)
        if updatedState != self.innerState {
            self.innerState = updatedState
            if let state = PermissionControllerState(updatedState) {
                self.transition(state: state, transition: transition)
            }
        }
    }
    
    private func transition(state: PermissionControllerState, transition: ContainedViewLayoutTransition) {
        let insets = state.layout.layout.insets(options: [.statusBar])
        let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: state.layout.navigationHeight), size: CGSize(width: state.layout.layout.size.width, height: state.layout.layout.size.height))
        
        if let state = state.data.state {
            switch state {
                case let .permission(permission):
                    if permission?.kind.rawValue != self.contentNode?.kind {
                        if let dataState = permission {
                            let icon: UIImage?
                            let title: String
                            let text: String
                            let buttonTitle: String
                            let hasPrivacyPolicy: Bool
                            
                            switch dataState {
                                case let .contacts(status):
                                    icon = UIImage(bundleImageName: "Settings/Permissions/Contacts")
                                    if let splitTest = self.splitTest, case let .modal(titleKey, textKey, allowTitleKey, allowInSettingsTitleKey) = splitTest.configuration.contacts {
                                        title = localizedString(for: titleKey, strings: self.presentationData.strings)
                                        text = localizedString(for: textKey, strings: self.presentationData.strings)
                                        if status == .denied {
                                            buttonTitle = localizedString(for: allowInSettingsTitleKey, strings: self.presentationData.strings)
                                        } else {
                                            buttonTitle = localizedString(for: allowTitleKey, strings: self.presentationData.strings)
                                        }
                                    } else {
                                        title = self.presentationData.strings.Permissions_ContactsTitle_v0
                                        text = self.presentationData.strings.Permissions_ContactsText_v0
                                        if status == .denied {
                                            buttonTitle = self.presentationData.strings.Permissions_ContactsAllowInSettings_v0
                                        } else {
                                            buttonTitle = self.presentationData.strings.Permissions_ContactsAllow_v0
                                        }
                                    }
                                    hasPrivacyPolicy = true
                                case let .notifications(status):
                                    icon = UIImage(bundleImageName: "Settings/Permissions/Notifications")
                                    if let splitTest = self.splitTest, case let .modal(titleKey, textKey, allowTitleKey, allowInSettingsTitleKey) = splitTest.configuration.notifications {
                                        title = localizedString(for: titleKey, strings: self.presentationData.strings, fallback: self.presentationData.strings.Permissions_NotificationsTitle_v0)
                                        text = localizedString(for: textKey, strings: self.presentationData.strings, fallback: self.presentationData.strings.Permissions_NotificationsText_v0)
                                        if status == .denied {
                                            buttonTitle = localizedString(for: allowInSettingsTitleKey, strings: self.presentationData.strings, fallback: self.presentationData.strings.Permissions_NotificationsAllowInSettings_v0)
                                        } else {
                                            buttonTitle = localizedString(for: allowTitleKey, strings: self.presentationData.strings, fallback: self.presentationData.strings.Permissions_NotificationsAllow_v0)
                                        }
                                    } else {
                                        title = self.presentationData.strings.Permissions_NotificationsTitle_v0
                                        text = self.presentationData.strings.Permissions_NotificationsText_v0
                                        if status == .denied {
                                            buttonTitle = self.presentationData.strings.Permissions_NotificationsAllowInSettings_v0
                                        } else {
                                            buttonTitle = self.presentationData.strings.Permissions_NotificationsAllow_v0
                                        }
                                    }
                                    hasPrivacyPolicy = false
                                case let .siri(status):
                                    icon = UIImage(bundleImageName: "Settings/Permissions/Siri")
                                    title = self.presentationData.strings.Permissions_SiriTitle_v0
                                    text = self.presentationData.strings.Permissions_SiriText_v0
                                    if status == .denied {
                                        buttonTitle = self.presentationData.strings.Permissions_SiriAllowInSettings_v0
                                    } else {
                                        buttonTitle = self.presentationData.strings.Permissions_SiriAllow_v0
                                    }
                                    hasPrivacyPolicy = false
                                case .cellularData:
                                    icon = UIImage(bundleImageName: "Settings/Permissions/CellularData")
                                    title = self.presentationData.strings.Permissions_CellularDataTitle_v0
                                    text = self.presentationData.strings.Permissions_CellularDataText_v0
                                    buttonTitle = self.presentationData.strings.Permissions_CellularDataAllowInSettings_v0
                                    hasPrivacyPolicy = false
                                case let .nearbyLocation(status):
                                    icon = nil
                                    title = self.presentationData.strings.Permissions_PeopleNearbyTitle_v0
                                    text = self.presentationData.strings.Permissions_PeopleNearbyText_v0
                                    if status == .denied {
                                        buttonTitle = self.presentationData.strings.Permissions_PeopleNearbyAllowInSettings_v0
                                    } else {
                                        buttonTitle = self.presentationData.strings.Permissions_PeopleNearbyAllow_v0
                                    }
                                    hasPrivacyPolicy = false
                            }
                            
                            let contentNode = PermissionContentNode(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, kind: dataState.kind.rawValue, icon: .image(icon), title: title, text: text, buttonTitle: buttonTitle, secondaryButtonTitle: nil, buttonAction: { [weak self] in
                                self?.allow?()
                                }, openPrivacyPolicy: hasPrivacyPolicy ? self.openPrivacyPolicy : nil)
                            self.insertSubnode(contentNode, at: 0)
                            contentNode.updateLayout(size: contentFrame.size, insets: insets, transition: .immediate)
                            contentNode.frame = contentFrame
                            if let currentContentNode = self.contentNode {
                                transition.updatePosition(node: currentContentNode, position: CGPoint(x: -contentFrame.size.width / 2.0, y: contentFrame.midY), completion: { [weak currentContentNode] _ in
                                    currentContentNode?.removeFromSupernode()
                                })
                                transition.animateHorizontalOffsetAdditive(node: contentNode, offset: -contentFrame.width)
                            } else if transition.isAnimated {
                                contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                            }
                            self.contentNode = contentNode
                        } else if let currentContentNode = self.contentNode {
                            transition.updateAlpha(node: currentContentNode, alpha: 0.0, completion: { [weak currentContentNode] _ in
                                currentContentNode?.removeFromSupernode()
                            })
                            self.contentNode = nil
                        }
                    } else if let contentNode = self.contentNode {
                        transition.updateFrame(node: contentNode, frame: contentFrame)
                        contentNode.updateLayout(size: contentFrame.size, insets: insets, transition: transition)
                    }
                case let .custom(icon, title, subtitle, text, buttonTitle, secondaryButtonTitle, footerText):
                    if let contentNode = self.contentNode {
                        transition.updateFrame(node: contentNode, frame: contentFrame)
                        contentNode.updateLayout(size: contentFrame.size, insets: insets, transition: transition)
                    } else {                        
                        let contentNode = PermissionContentNode(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, kind: 0, icon: icon, title: title, subtitle: subtitle, text: text, buttonTitle: buttonTitle, secondaryButtonTitle: secondaryButtonTitle, footerText: footerText, buttonAction: { [weak self] in
                            self?.allow?()
                        }, openPrivacyPolicy: secondaryButtonTitle != nil ? { [weak self] in
                            self?.dismiss?()
                        } : nil)
                        self.insertSubnode(contentNode, at: 0)
                        contentNode.updateLayout(size: contentFrame.size, insets: insets, transition: .immediate)
                        contentNode.frame = contentFrame
                        self.contentNode = contentNode
                    }
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.updateState({ state in
            var state = state
            state.layout = PermissionControllerLayoutState(layout: layout, navigationHeight: navigationBarHeight)
            return state
        }, transition: transition)
    }
    
    @objc func privacyPolicyPressed() {
        self.openPrivacyPolicy?()
    }
}
