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
    var flat: Bool
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
        var flatModal: Bool = false
        switch controller.navigationPresentation {
        case .default:
            requiresModal = false
        case .master:
            requiresModal = false
        case .modal:
            requiresModal = true
            beginsModal = true
        case .flatModal:
            requiresModal = true
            beginsModal = true
            flatModal = true
        case .modalInLargeLayout:
            switch layout.metrics.widthClass {
            case .compact:
                requiresModal = false
            case .regular:
                requiresModal = true
            }
        }
        if requiresModal {
            controller._presentedInModal = true
            if beginsModal || modalStack.isEmpty {
                modalStack.append(ModalContainerLayout(controllers: [controller], flat: flatModal))
            } else {
                modalStack[modalStack.count - 1].controllers.append(controller)
            }
        } else if !modalStack.isEmpty {
            controller._presentedInModal = true
            modalStack[modalStack.count - 1].controllers.append(controller)
        } else {
            controller._presentedInModal = false
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
