import Foundation
import LegacyComponents
import Display

final class LegacyEmptyController: TGViewController {
    override init!(context: LegacyComponentsContext!) {
        super.init(context: context)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        self.view.backgroundColor = nil
        self.view.isOpaque = false
    }
}
