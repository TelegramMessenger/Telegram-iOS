import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

enum RootNavigationLayout {
    case split([ViewController], [ViewController])
    case flat([ViewController])
}

struct ModalContainerLayout {
    var controllers: [ViewController]
    var isStandalone: Bool
}

struct NavigationLayout {
    var root: RootNavigationLayout
    var modal: [ModalContainerLayout]
}

func makeNavigationLayout(mode: NavigationControllerMode, layout: ContainerViewLayout, controllers: [ViewController]) -> NavigationLayout {
    var rootControllers: [ViewController] = []
    var modalStack: [ModalContainerLayout] = []
    for controller in controllers {
        let requiresModal: Bool
        var beginsModal: Bool = false
        var isStandalone: Bool = false
        switch controller.navigationPresentation {
        case .default:
            requiresModal = false
        case .master:
            requiresModal = false
        case .modal:
            requiresModal = true
            beginsModal = true
        case .standaloneModal:
            requiresModal = true
            beginsModal = true
            isStandalone = true
        case .modalInLargeLayout:
            switch layout.metrics.widthClass {
            case .compact:
                requiresModal = false
            case .regular:
                requiresModal = true
            }
        }
        if requiresModal {
            if beginsModal || modalStack.isEmpty || modalStack[modalStack.count - 1].isStandalone {
                modalStack.append(ModalContainerLayout(controllers: [controller], isStandalone: isStandalone))
            } else {
                modalStack[modalStack.count - 1].controllers.append(controller)
            }
        } else if !modalStack.isEmpty {
            if modalStack[modalStack.count - 1].isStandalone {
                modalStack.append(ModalContainerLayout(controllers: [controller], isStandalone: isStandalone))
            } else {
                modalStack[modalStack.count - 1].controllers.append(controller)
            }
        } else {
            rootControllers.append(controller)
        }
    }
    let rootLayout: RootNavigationLayout
    switch mode {
    case .single:
        rootLayout = .flat(rootControllers)
    case .automaticMasterDetail:
        switch layout.metrics.widthClass {
        case .compact:
            rootLayout = .flat(rootControllers)
        case .regular:
            let masterControllers = rootControllers.filter {
                if case .master = $0.navigationPresentation {
                    return true
                } else {
                    return false
                }
            }
            let detailControllers = rootControllers.filter {
                if case .master = $0.navigationPresentation {
                    return false
                } else {
                    return true
                }
            }
            rootLayout = .split(masterControllers, detailControllers)
        }
    }
    return NavigationLayout(root: rootLayout, modal: modalStack)
}
