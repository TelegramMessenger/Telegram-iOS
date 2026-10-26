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
    private let scrubber = DemoScrubberView()
    private let frameMonitor = FrameMonitor()
    private let hudLabel = UILabel()
    private let resetButton = UIButton(type: .system)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
    private var autoScrubLink: CADisplayLink?
    private var autoScrubStep = 0
    private let sourceControl = UISegmentedControl(items: ["Synthetic 100k", "Photo Library"])

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.sourceControl.selectedSegmentIndex = Source.synthetic.rawValue
        self.sourceControl.addTarget(self, action: #selector(self.sourceChanged), for: .valueChanged)
        self.navigationItem.titleView = self.sourceControl
        self.installGrid(dataSource: self.syntheticDataSource)

        self.scrubber.onChange = { [weak self] fraction in
            guard let self, let gridView = self.gridView else {
                return
            }
            gridView.setContentOffset(fraction * max(0.0, gridView.contentHeight - gridView.bounds.height))
            self.updateScrubberDate()
        }
        self.view.addSubview(self.scrubber)

        self.hudLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11.0, weight: .medium)
        self.hudLabel.textColor = .white
        self.hudLabel.numberOfLines = 2
        self.hudLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.view.addSubview(self.hudLabel)
        self.resetButton.setTitle("Reset", for: .normal)
        self.resetButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.resetButton.addTarget(self, action: #selector(self.resetPressed), for: .touchUpInside)
        self.view.addSubview(self.resetButton)
        self.frameMonitor.onUpdate = { [weak self] summary in
            self?.hudLabel.text = String(format: "frames %d  dropped %d\nworst(5s) %.1f ms", summary.frames, summary.dropped, summary.worst * 1000.0)
        }
        self.frameMonitor.start()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if ProcessInfo.processInfo.arguments.contains("-autoScrub") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startAutoScrub()
            }
        }
    }

    @objc private func resetPressed() {
        self.frameMonitor.reset()
    }

    private func updateScrubberDate() {
        self.scrubber.dateText = self.gridView?.topVisibleDate.map { self.dateFormatter.string(from: $0) }
    }

    private func startAutoScrub() {
        guard self.autoScrubLink == nil, let gridView = self.gridView else {
            return
        }
        gridView.layoutIfNeeded()
        self.frameMonitor.reset()
        self.autoScrubStep = 0
        let link = CADisplayLink(target: self, selector: #selector(self.autoScrubTick))
        link.add(to: .main, forMode: .common)
        self.autoScrubLink = link
    }

    @objc private func autoScrubTick() {
        guard let gridView = self.gridView else {
            return
        }
        let steps = 120
        let step = self.autoScrubStep
        self.autoScrubStep += 1
        let maximum = max(0.0, gridView.contentHeight - gridView.bounds.height)
        if step <= steps {
            gridView.setContentOffset(maximum * CGFloat(step) / CGFloat(steps))
        } else if step <= 2 * steps {
            gridView.setContentOffset(maximum * CGFloat(2 * steps - step) / CGFloat(steps))
        } else {
            self.autoScrubLink?.invalidate()
            self.autoScrubLink = nil
            let summary = self.frameMonitor.summary
            print(String(format: "AUTOSCRUB frames=%d dropped=%d worst=%.2fms avg=%.2fms steps=%d (simulator-only)", summary.frames, summary.dropped, self.frameMonitor.overallWorst * 1000.0, summary.average * 1000.0, 2 * steps))
            fflush(stdout)
        }
    }

    private func installGrid(dataSource: MediaGridDataSource) {
        self.gridView?.removeFromSuperview()
        let gridView = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        gridView.onScroll = { [weak self] offset in
            guard let self, let gridView = self.gridView else {
                return
            }
            let range = max(0.0, gridView.contentHeight - gridView.bounds.height)
            self.scrubber.setFraction(range > 0.0 ? offset / range : 0.0)
            self.updateScrubberDate()
        }
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
        let insets = self.view.safeAreaInsets
        self.scrubber.frame = CGRect(x: self.view.bounds.width - 220.0, y: insets.top, width: 220.0, height: self.view.bounds.height - insets.top - insets.bottom)
        self.hudLabel.frame = CGRect(x: 8.0, y: insets.top + 8.0, width: 170.0, height: 32.0)
        self.resetButton.frame = CGRect(x: 8.0, y: self.hudLabel.frame.maxY + 4.0, width: 60.0, height: 28.0)
    }
}
