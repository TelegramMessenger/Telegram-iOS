import Foundation
import TelegramLegacyComponents

final class LegacyEmptyController: TGViewController {
    override func viewDidLoad() {
        self.view.backgroundColor = nil
        self.view.isOpaque = false
    }
}
