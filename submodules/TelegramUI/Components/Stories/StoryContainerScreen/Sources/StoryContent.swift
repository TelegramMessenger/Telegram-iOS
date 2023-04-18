import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit

public final class StoryContentItem {
    public let id: AnyHashable
    public let position: Int
    public let component: AnyComponent<Empty>
    public let centerInfoComponent: AnyComponent<Empty>?
    public let rightInfoComponent: AnyComponent<Empty>?

    public init(
        id: AnyHashable,
        position: Int,
        component: AnyComponent<Empty>,
        centerInfoComponent: AnyComponent<Empty>?,
        rightInfoComponent: AnyComponent<Empty>?
    ) {
        self.id = id
        self.position = position
        self.component = component
        self.centerInfoComponent = centerInfoComponent
        self.rightInfoComponent = rightInfoComponent
    }
}

public final class StoryContentItemSlice {
    public let focusedItemId: AnyHashable
    public let items: [StoryContentItem]
    public let totalCount: Int
    public let update: (StoryContentItemSlice, AnyHashable) -> Signal<StoryContentItemSlice, NoError>

    public init(
        focusedItemId: AnyHashable,
        items: [StoryContentItem],
        totalCount: Int,
        update: @escaping (StoryContentItemSlice, AnyHashable) -> Signal<StoryContentItemSlice, NoError>
    ) {
        self.focusedItemId = focusedItemId
        self.items = items
        self.totalCount = totalCount
        self.update = update
    }
}
