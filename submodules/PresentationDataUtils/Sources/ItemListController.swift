import Foundation
import Display
import AlertUI
import AccountContext
import SwiftSignalKit
import ItemListUI

public extension ItemListController {
    convenience init<ItemGenerationArguments>(context: AccountContext, state: Signal<(ItemListControllerState, (ItemListNodeState, ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>? = nil, hideNavigationBarBackground: Bool = false) {
        self.init(sharedContext: context.sharedContext, state: state, tabBarItem: tabBarItem, hideNavigationBarBackground: hideNavigationBarBackground)
    }
    
    convenience init<ItemGenerationArguments>(sharedContext: SharedAccountContext, state: Signal<(ItemListControllerState, (ItemListNodeState, ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>? = nil, hideNavigationBarBackground: Bool = false) {
        let presentationData = sharedContext.currentPresentationData.with { $0 }
        self.init(presentationData: ItemListPresentationData(presentationData), updatedPresentationData: sharedContext.presentationData |> map(ItemListPresentationData.init(_:)), state: state, tabBarItem: tabBarItem, hideNavigationBarBackground: hideNavigationBarBackground)
    }
}
