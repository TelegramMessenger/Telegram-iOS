import UIKit
import Photos
import MediaGrid

final class DemoViewController: UIViewController {
    private enum Source: Int {
        case synthetic
        case photoLibrary
    }

    private let syntheticDataSource = SyntheticDataSource()
    private var photoDataSource: PhotoLibraryDataSource?
    private var gridView: MediaGridView?
    private let sourceControl = UISegmentedControl(items: ["Synthetic 100k", "Photo Library"])

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.sourceControl.selectedSegmentIndex = Source.synthetic.rawValue
        self.sourceControl.addTarget(self, action: #selector(self.sourceChanged), for: .valueChanged)
        self.navigationItem.titleView = self.sourceControl
        self.installGrid(dataSource: self.syntheticDataSource)
    }

    private func installGrid(dataSource: MediaGridDataSource) {
        self.gridView?.removeFromSuperview()
        let gridView = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        self.view.insertSubview(gridView, at: 0)
        self.gridView = gridView
        self.view.setNeedsLayout()
    }

    @objc private func sourceChanged() {
        switch Source(rawValue: self.sourceControl.selectedSegmentIndex) ?? .synthetic {
        case .synthetic:
            self.installGrid(dataSource: self.syntheticDataSource)
        case .photoLibrary:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    guard let self, self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue else {
                        return
                    }
                    if status == .authorized || status == .limited {
                        let dataSource = PhotoLibraryDataSource(fetchResult: PhotoLibraryDataSource.makeFetchResult())
                        self.photoDataSource = dataSource
                        self.installGrid(dataSource: dataSource)
                    } else {
                        self.sourceControl.selectedSegmentIndex = Source.synthetic.rawValue
                        self.installGrid(dataSource: self.syntheticDataSource)
                    }
                }
            }
        }
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
