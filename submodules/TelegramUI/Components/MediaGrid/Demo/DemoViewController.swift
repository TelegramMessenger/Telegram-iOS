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
    private var selectedIndices: Set<Int> = []
    private let bannerView = UILabel()
    private let scrubber = DemoScrubberView()
    private let frameMonitor = FrameMonitor()
    private let hudLabel = UILabel()
    private let resetButton = UIButton(type: .system)
    private let zoomInButton = UIButton(type: .system)
    private let zoomOutButton = UIButton(type: .system)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
    private var autoScrubLink: CADisplayLink?
    private var autoScrubStep = 0
    private var autoPinchLink: CADisplayLink?
    private var autoPinchStart: CFTimeInterval?
    private var autoPinchState: MediaGridPinchState?
    private var autoPinchPair: String?
    private var autoPinchCentre: CGPoint = .zero
    private var autoPinchScale: CGFloat = 1.0
    private var autoPinchVelocity: CGFloat = 0.0
    private var autoPinchLastTimestamp: CFTimeInterval?
    private var autoPinchDriveWorst: CFTimeInterval = 0.0
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
        for (button, title, action) in [(self.zoomInButton, "Zoom In", #selector(self.zoomInPressed)), (self.zoomOutButton, "Zoom Out", #selector(self.zoomOutPressed))] {
            button.setTitle(title, for: .normal)
            button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            button.addTarget(self, action: action, for: .touchUpInside)
            self.view.addSubview(button)
        }
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
        if ProcessInfo.processInfo.arguments.contains("-autoPinch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.startAutoPinch()
            }
        }
    }

    private func startAutoPinch() {
        #if DEBUG
        guard self.autoPinchLink == nil, let gridView = self.gridView else {
            return
        }
        gridView.layoutIfNeeded()
        gridView.setContentOffset(gridView.contentHeight * 0.4)
        self.autoPinchCentre = CGPoint(x: gridView.bounds.midX, y: gridView.bounds.midY)
        self.autoPinchStart = nil
        self.autoPinchScale = 1.0
        self.autoPinchLastTimestamp = nil
        self.autoPinchPair = nil
        self.autoPinchState = MediaGridPinchState(startLevel: gridView.level, anchor: MediaGridZoomAnchor(index: 0, pointInView: self.autoPinchCentre))
        let link = CADisplayLink(target: self, selector: #selector(self.autoPinchTick(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
        }
        link.add(to: .main, forMode: .common)
        self.autoPinchLink = link
        #endif
    }

    private func reportAutoPinchPair() {
        if let pair = self.autoPinchPair {
            let summary = self.frameMonitor.summary
            print(String(format: "AUTOPINCH pair=%@ frames=%d dropped=%d worst=%.2fms avg=%.2fms drive_worst=%.2fms (simulator-only)", pair, summary.frames, summary.dropped, self.frameMonitor.overallWorst * 1000.0, summary.average * 1000.0, self.autoPinchDriveWorst * 1000.0))
            fflush(stdout)
        }
        self.frameMonitor.reset()
        self.autoPinchDriveWorst = 0.0
    }

    @objc private func autoPinchTick(_ link: CADisplayLink) {
        #if DEBUG
        guard let gridView = self.gridView, var state = self.autoPinchState else {
            return
        }
        let start = self.autoPinchStart ?? link.timestamp
        self.autoPinchStart = start
        let elapsed = link.timestamp - start
        let outDuration = 1.2
        let backDuration = 0.8
        let deepest = log(3.0 / 31.0)
        if elapsed == 0.0 {
            self.frameMonitor.reset()
            gridView.debugDrivePinch(.began, center: self.autoPinchCentre, scale: 1.0, velocity: 0.0)
            return
        }
        let exponent: CGFloat
        if elapsed < outDuration {
            exponent = deepest * CGFloat(elapsed / outDuration)
        } else if elapsed < outDuration + backDuration {
            exponent = deepest * CGFloat(1.0 - (elapsed - outDuration) / backDuration)
        } else {
            self.reportAutoPinchPair()
            gridView.debugDrivePinch(.ended, center: self.autoPinchCentre, scale: 1.0, velocity: 0.0)
            self.autoPinchLink?.invalidate()
            self.autoPinchLink = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                print("AUTOPINCH done level=\(self?.gridView?.level.columns ?? 0)")
                fflush(stdout)
            }
            return
        }
        let scale = exp(exponent)
        if let last = self.autoPinchLastTimestamp, link.timestamp > last {
            self.autoPinchVelocity = (scale - self.autoPinchScale) / CGFloat(link.timestamp - last)
        }
        self.autoPinchLastTimestamp = link.timestamp
        self.autoPinchScale = scale
        let result = state.update(scale: scale)
        self.autoPinchState = state
        let pair = result.from == result.to ? "\(result.from.columns)" : "\(min(result.from.columns, result.to.columns))<->\(max(result.from.columns, result.to.columns))"
        if pair != self.autoPinchPair {
            self.reportAutoPinchPair()
            self.autoPinchPair = pair
        }
        let driveStart = CACurrentMediaTime()
        gridView.debugDrivePinch(.changed, center: self.autoPinchCentre, scale: scale, velocity: self.autoPinchVelocity)
        CATransaction.flush()
        self.autoPinchDriveWorst = max(self.autoPinchDriveWorst, CACurrentMediaTime() - driveStart)
        #endif
    }

    @objc private func resetPressed() {
        self.frameMonitor.reset()
    }

    @objc private func zoomInPressed() {
        self.gridView?.zoomIn()
    }

    @objc private func zoomOutPressed() {
        self.gridView?.zoomOut()
    }

    private func updateZoomButtons() {
        self.zoomInButton.isEnabled = self.gridView?.canZoomIn ?? false
        self.zoomOutButton.isEnabled = self.gridView?.canZoomOut ?? false
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
            return DemoCellLayer()
        })
        self.selectedIndices = []
        let camera = UIView()
        camera.backgroundColor = UIColor(white: 0.35, alpha: 1.0)
        gridView.cameraView = camera
        gridView.isItemSelected = { [weak self] index in
            return self?.selectedIndices.contains(index) ?? false
        }
        gridView.onTapItem = { [weak self] index in
            self?.toggle(index)
        }
        gridView.onSelectionPan = { [weak self] index, select in
            if select {
                self?.selectedIndices.insert(index)
            } else {
                self?.selectedIndices.remove(index)
            }
        }
        gridView.onScroll = { [weak self] offset in
            guard let self, let gridView = self.gridView else {
                return
            }
            let range = max(0.0, gridView.contentHeight - gridView.bounds.height)
            self.scrubber.setFraction(range > 0.0 ? offset / range : 0.0)
            self.updateScrubberDate()
        }
        gridView.onLevelChanged = { [weak self] _ in
            self?.updateZoomButtons()
        }
        self.view.insertSubview(gridView, at: 0)
        self.gridView = gridView
        self.updateZoomButtons()
        self.view.setNeedsLayout()
    }

    private func toggle(_ index: Int) {
        if self.selectedIndices.contains(index) {
            self.selectedIndices.remove(index)
        } else {
            self.selectedIndices.insert(index)
        }
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
        self.bannerView.text = "Banner placeholder"
        self.bannerView.textAlignment = .center
        self.bannerView.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.8)
        if self.bannerView.superview == nil {
            self.view.insertSubview(self.bannerView, aboveSubview: gridView)
        }
        self.bannerView.frame = CGRect(x: 0.0, y: self.view.safeAreaInsets.top, width: self.view.bounds.width, height: 44.0)
        gridView.geometryInsets = UIEdgeInsets(top: self.view.safeAreaInsets.top + 44.0, left: 0.0, bottom: self.view.safeAreaInsets.bottom, right: 0.0)
        let insets = self.view.safeAreaInsets
        self.scrubber.frame = CGRect(x: self.view.bounds.width - 220.0, y: insets.top, width: 220.0, height: self.view.bounds.height - insets.top - insets.bottom)
        self.hudLabel.frame = CGRect(x: 8.0, y: insets.top + 8.0, width: 170.0, height: 32.0)
        self.resetButton.frame = CGRect(x: 8.0, y: self.hudLabel.frame.maxY + 4.0, width: 60.0, height: 28.0)
        self.zoomInButton.frame = CGRect(x: 8.0, y: self.view.bounds.height - insets.bottom - 40.0, width: 84.0, height: 32.0)
        self.zoomOutButton.frame = CGRect(x: self.zoomInButton.frame.maxX + 8.0, y: self.zoomInButton.frame.minY, width: 84.0, height: 32.0)
    }
}
