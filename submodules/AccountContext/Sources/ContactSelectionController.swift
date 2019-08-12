import Foundation
import Display
import SwiftSignalKit

public protocol ContactSelectionController: ViewController {
    var result: Signal<ContactListPeer?, NoError> { get }
    
    func dismissSearch()
}
