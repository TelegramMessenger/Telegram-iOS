import SwiftSignalKit
import Postbox

public extension TelegramEngine.EngineData.Item {
    enum ChatList {
        public struct FiltersDisplayTags: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            public init() {
            }

            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.chatListFilters]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                let state = view.values[PreferencesKeys.chatListFilters]?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
                return state.displayTags
            }
        }
    }
}
