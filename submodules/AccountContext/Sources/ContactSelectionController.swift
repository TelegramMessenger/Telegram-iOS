import Foundation
import Display
import SwiftSignalKit

public protocol ContactSelectionController: ViewController {
    var result: Signal<([ContactListPeer], ContactListAction, Bool, Int32?)?, NoError> { get }
    var displayProgress: Bool { get set }
    var dismissed: (() -> Void)? { get set }
    
    func dismissSearch()
}
