import Foundation
import Display
import AlertUI
import AccountContext
import SwiftSignalKit
import ItemListUI

public extension ItemListController {
    convenience init<ItemGenerationArguments>(context: AccountContext, state: Signal<(ItemListControllerState, (ItemListNodeState, ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>? = nil) {
        self.init(sharedContext: context.sharedContext, state: state, tabBarItem: tabBarItem)
    }
    
    convenience init<ItemGenerationArguments>(sharedContext: SharedAccountContext, state: Signal<(ItemListControllerState, (ItemListNodeState, ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>? = nil) {
        let presentationData = sharedContext.currentPresentationData.with { $0 }
        self.init(presentationData: ItemListPresentationData(presentationData), updatedPresentationData: sharedContext.presentationData |> map(ItemListPresentationData.init(_:)), state: state, tabBarItem: tabBarItem)
    }
}
