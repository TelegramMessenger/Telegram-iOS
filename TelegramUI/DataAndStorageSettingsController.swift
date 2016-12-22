import Foundation
import Display
import Postbox
import SwiftSignalKit
import TelegramCore
import MtProtoKitDynamic

public class DataAndStorageSettingsController: ListController {
    private let account: Account
    
    private var currentStatsDisposable: Disposable?
    
    public init(account: Account) {
        self.account = account
        
        super.init()
        
        self.title = "Data and Storage"
        
        let deselectAction = { [weak self] () -> Void in
            self?.listDisplayNode.listView.clearHighlightAnimated(true)
        }
        
        self.items = [
            ListControllerDisclosureActionItem(title: "Bytes Sent", action: deselectAction),
            ListControllerDisclosureActionItem(title: "Bytes Received", action: deselectAction),
        ]
        
        self.currentStatsDisposable = (((account.currentNetworkStats() |> then(Signal<MTNetworkUsageManagerStats, NoError>.complete() |> delay(1.0, queue: Queue.concurrentDefaultQueue()))) |> restart) |> deliverOnMainQueue).start(next: { [weak self] stats in
            if let strongSelf = self {
                let incoming = stats.wwan.incomingBytes + stats.other.incomingBytes
                let outgoing = stats.wwan.outgoingBytes + stats.other.outgoingBytes
                strongSelf.listDisplayNode.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [ListViewUpdateItem(index: 0, previousIndex: 0, item: ListControllerDisclosureActionItem(title: "Bytes Sent: \(outgoing / 1024) KB", action: deselectAction), directionHint: nil), ListViewUpdateItem(index: 1, previousIndex: 1, item: ListControllerDisclosureActionItem(title: "Bytes Received: \(incoming / 1024) KB", action: deselectAction), directionHint: nil)], options: [.AnimateInsertion], updateOpaqueState: nil)
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        currentStatsDisposable?.dispose()
    }
}
