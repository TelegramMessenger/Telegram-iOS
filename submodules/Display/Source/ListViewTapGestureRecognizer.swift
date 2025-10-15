import Foundation
import UIKit

public final class ListViewTapGestureRecognizer: UITapGestureRecognizer {
    public func cancel() {
        self.state = .failed
    }
}
