import UIKit
import Display
import ContextUI
import TelegramPresentationData
import TelegramCore

private final class LocationLiveLocationReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    
    init(sourceView: UIView) {
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}

func makeLiveLocationDurationContextController(
    presentationData: PresentationData,
    sourceView: UIView,
    title: String,
    selectPeriod: @escaping (Int32) -> Void
) -> ViewController {
    let noAction: ((ContextMenuActionItem.Action) -> Void)? = nil
    var items: [ContextMenuItem] = []
    
    items.append(.action(ContextMenuActionItem(
        text: title,
        textLayout: .multiline,
        textFont: .small,
        parseMarkdown: true,
        icon: { _ in
            return nil
        },
        action: noAction
    )))
    
    items.append(.separator)
    
    let periodItems: [(String, Int32)] = [
        (presentationData.strings.Map_LiveLocationForMinutes(15), 15 * 60),
        (presentationData.strings.Map_LiveLocationForHours(1), 60 * 60 - 1),
        (presentationData.strings.Map_LiveLocationForHours(8), 8 * 60 * 60),
        (presentationData.strings.Map_LiveLocationIndefinite, liveLocationIndefinitePeriod)
    ]
    
    for (text, period) in periodItems {
        items.append(.action(ContextMenuActionItem(
            text: text,
            icon: { _ in
                return nil
            },
            action: { _, f in
                f(.default)
                selectPeriod(period)
            }
        )))
    }
    
    let contextController = makeContextController(
        presentationData: presentationData,
        source: .reference(LocationLiveLocationReferenceContentSource(sourceView: sourceView)),
        items: .single(ContextController.Items(content: .list(items))),
        gesture: nil
    )
    return contextController
}
