import UIKit
import MediaGrid

final class DemoViewController: UIViewController {
    private let dataSource = SyntheticDataSource()
    private var gridView: MediaGridView?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        let gridView = MediaGridView(dataSource: self.dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        self.view.addSubview(gridView)
        self.gridView = gridView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let gridView = self.gridView else {
            return
        }
        gridView.frame = self.view.bounds
        gridView.geometryInsets = UIEdgeInsets(top: self.view.safeAreaInsets.top, left: 0.0, bottom: self.view.safeAreaInsets.bottom, right: 0.0)
    }
}
