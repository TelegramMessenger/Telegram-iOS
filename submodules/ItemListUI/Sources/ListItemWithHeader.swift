import Foundation
import Display

public protocol ListViewItemWithHeader: ListViewItem {
    var header: ListViewItemHeader? { get }
}
