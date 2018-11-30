import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

enum PermissionStateKind: Int32 {
    case contacts
    case notifications
    case siri
    case cellularData
}

private enum PermissionRequestStatus {
    case requestable
    case denied
}

private enum PermissionNotificationsRequestStatus {
    case requestable
    case denied
    case unreachable
}

private enum PermissionState: Equatable {
    case contacts(status: PermissionRequestStatus)
    case notifications(status: PermissionNotificationsRequestStatus)
    case siri(status: PermissionRequestStatus)
    case cellularData
    
    var kind: PermissionStateKind {
        switch self {
            case .contacts:
                return .contacts
            case .notifications:
                return .notifications
            case .siri:
                return .siri
            case .cellularData:
                return .cellularData
        }
    }
}

private struct PermissionControllerDataState: Equatable {
    var state: PermissionState?
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

final class PermissionControllerNode: ASDisplayNode {
    private let account: Account
    private var presentationData: PresentationData
    
    private var innerState: PermissionControllerInnerState
    
    private var contentNode: PermissionContentNode?
    
    var allow: (() -> Void)?
    var openPrivacyPolicy: (() -> Void)?
    var dismiss: (() -> Void)?
    
    init(account: Account) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.innerState = PermissionControllerInnerState(layout: nil, data: PermissionControllerDataState(state: nil))
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.applyPresentationData()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.applyPresentationData()
    }
    
    private func applyPresentationData() {
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor    }
    
    func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
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
        let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: state.layout.layout.size.width, height: state.layout.layout.size.height))
        
        if state.data.state?.kind != self.contentNode?.kind {
            if let dataState = state.data.state {
                let icon: UIImage?
                let title: String
                let text: String
                let buttonTitle: String
                let hasPrivacyPolicy: Bool

                switch dataState {
                    case let .contacts(status):
                        icon = UIImage(bundleImageName: "Settings/Permissions/Contacts")
                        title = self.presentationData.strings.Permissions_ContactsTitle
                        text = self.presentationData.strings.Permissions_ContactsText
                        if status == .denied {
                            buttonTitle = self.presentationData.strings.Permissions_ContactsAllowInSettings
                        } else {
                            buttonTitle = self.presentationData.strings.Permissions_ContactsAllow
                        }
                        hasPrivacyPolicy = true
                    case let .notifications(status):
                        icon = UIImage(bundleImageName: "Settings/Permissions/Notifications")
                        title = self.presentationData.strings.Permissions_NotificationsTitle
                        text = self.presentationData.strings.Permissions_NotificationsText
                        if status == .denied {
                            buttonTitle = self.presentationData.strings.Permissions_NotificationsAllowInSettings
                        } else {
                            buttonTitle = self.presentationData.strings.Permissions_NotificationsAllow
                        }
                        hasPrivacyPolicy = false
                    case let .siri(status):
                        icon = UIImage(bundleImageName: "Settings/Permissions/Siri")
                        title = self.presentationData.strings.Permissions_SiriTitle
                        text = self.presentationData.strings.Permissions_SiriText
                        if status == .denied {
                            buttonTitle = self.presentationData.strings.Permissions_SiriAllowInSettings
                        } else {
                            buttonTitle = self.presentationData.strings.Permissions_SiriAllow
                        }
                        hasPrivacyPolicy = false
                    case .cellularData:
                        icon = UIImage(bundleImageName: "Settings/Permissions/CellularData")
                        title = self.presentationData.strings.Permissions_CellularDataTitle
                        text = self.presentationData.strings.Permissions_CellularDataText
                        buttonTitle = self.presentationData.strings.Permissions_CellularDataAllowInSettings
                        hasPrivacyPolicy = false
                }

                let contentNode = PermissionContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, kind: dataState.kind, icon: icon, title: title, text: text, buttonTitle: buttonTitle, buttonAction: {}, openPrivacyPolicy: hasPrivacyPolicy ? self.openPrivacyPolicy : nil)
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
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.updateState({ state in
            var state = state
            state.layout = PermissionControllerLayoutState(layout: layout, navigationHeight: navigationBarHeight)
            return state
        }, transition: transition)
    }
    
    func activateNextAction() {
        
    }
    
    @objc func allowPressed() {
        self.allow?()
    }
    
    @objc func privacyPolicyPressed() {
        self.openPrivacyPolicy?()
    }
}
