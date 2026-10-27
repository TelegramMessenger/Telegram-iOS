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
    private var instrumentedDataSource: InstrumentedDataSource?
    private var gridView: MediaGridView?
    private var selectedIndices: Set<Int> = []
    private let bannerView = UILabel()
    private let scrubber = DemoScrubberView()
    private let frameMonitor = FrameMonitor()
    private let hudLabel = UILabel()
    private let resetButton = UIButton(type: .system)
    private let zoomInButton = UIButton(type: .system)
    private let zoomOutButton = UIButton(type: .system)
    private let measureButton = UIButton(type: .system)
    private var isMeasuringAspects = false
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
    private var autoScrubLink: CADisplayLink?
    private var autoScrubStep = 0
    private var autoScrubLastTimestamp: CFTimeInterval?
    private var autoScrubEmptyFrames = 0
    private var autoScrubEmptyMax = 0
    private var autoScrubEmptyTotal = 0
    private var autoScrubVisibleTotal = 0
    private var autoScrubWorkWorst: CFTimeInterval = 0.0
    private var autoScrubSettleStart: CFTimeInterval?
    private var autoPinchLink: CADisplayLink?
    private var autoPinchStart: CFTimeInterval?
    private var autoPinchState: MediaGridPinchState?
    private var autoPinchPair: String?
    private var autoPinchCentre: CGPoint = .zero
    private var autoPinchScale: CGFloat = 1.0
    private var autoPinchVelocity: CGFloat = 0.0
    private var autoPinchLastTimestamp: CFTimeInterval?
    private var autoPinchDriveWorst: CFTimeInterval = 0.0
    private var benchmark: PhotoLibraryBenchmark?
    private let sourceControl = UISegmentedControl(items: ["Synthetic 100k", "Photo Library"])

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.sourceControl.selectedSegmentIndex = Source.synthetic.rawValue
        self.sourceControl.addTarget(self, action: #selector(self.sourceChanged), for: .valueChanged)
        self.navigationItem.titleView = self.sourceControl
        self.installGrid(dataSource: self.syntheticDataSource)
        if DemoViewController.argument("-source") == "photos" {
            self.sourceControl.selectedSegmentIndex = Source.photoLibrary.rawValue
            self.sourceChanged()
        }

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
        self.measureButton.setTitle("Measure aspects", for: .normal)
        self.measureButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.measureButton.addTarget(self, action: #selector(self.measureAspectsPressed), for: .touchUpInside)
        self.view.addSubview(self.measureButton)
        self.frameMonitor.onUpdate = { [weak self] summary in
            self?.hudLabel.text = String(format: "frames %d  dropped %d\nworst(5s) %.1f ms", summary.frames, summary.dropped, summary.worst * 1000.0)
        }
        self.frameMonitor.start()
    }

    private static func argument(_ name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    private var launchLevel: MediaGridLevel? {
        return DemoViewController.argument("-level").flatMap(Int.init).flatMap(MediaGridLevel.init(rawValue:))
    }

    private func startBenchmarkIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard self.benchmark == nil, let mode = ["-benchPhotos", "-benchThroughput", "-benchBatch"].first(where: arguments.contains) else {
            return
        }
        let benchmark = PhotoLibraryBenchmark(fetchResult: PhotoLibraryDataSource.makeFetchResult())
        self.benchmark = benchmark
        let completion: () -> Void = { [weak self] in
            print("BENCH done")
            fflush(stdout)
            self?.benchmark = nil
        }
        switch mode {
        case "-benchThroughput":
            benchmark.runThroughput(completion: completion)
        case "-benchBatch":
            benchmark.runBatchCaching(completion: completion)
        default:
            benchmark.run(completion: completion)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.startBenchmarkIfRequested()
        if ProcessInfo.processInfo.arguments.contains("-autoScrub") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startAutoScrub()
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-measureAspects") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.measureAspectsPressed()
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

    @objc private func measureAspectsPressed() {
        guard !self.isMeasuringAspects else {
            return
        }
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited else {
            self.showMeasurement("Photo Library access is needed")
            return
        }
        self.isMeasuringAspects = true
        self.measureButton.isEnabled = false
        DispatchQueue.global(qos: .userInitiated).async {
            let enumerated = PhotoLibraryDataSource.makeFetchResult()
            var enumerateSum = 0.0
            let enumerateStart = CACurrentMediaTime()
            enumerated.enumerateObjects { asset, _, _ in
                enumerateSum += Double(asset.pixelWidth) / Double(max(1, asset.pixelHeight))
            }
            let enumerateTime = CACurrentMediaTime() - enumerateStart

            let indexed = PhotoLibraryDataSource.makeFetchResult()
            var indexedSum = 0.0
            let indexedStart = CACurrentMediaTime()
            for index in 0 ..< indexed.count {
                let asset = indexed.object(at: index)
                indexedSum += Double(asset.pixelWidth) / Double(max(1, asset.pixelHeight))
            }
            let indexedTime = CACurrentMediaTime() - indexedStart

            let text = String(format: "count %d\nenumerateObjects %.0f ms\nobject(at:) %.0f ms", enumerated.count, enumerateTime * 1000.0, indexedTime * 1000.0)
            print(String(format: "MEASURE_ASPECTS count=%d enumerate=%.1fms object_at=%.1fms check=%d", enumerated.count, enumerateTime * 1000.0, indexedTime * 1000.0, abs(enumerateSum - indexedSum) < 1e-6 ? 1 : 0))
            fflush(stdout)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.isMeasuringAspects = false
                self.measureButton.isEnabled = true
                self.showMeasurement(text)
            }
        }
    }

    private func showMeasurement(_ text: String) {
        let alert = UIAlertController(title: "Aspect read", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
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
        self.autoScrubLastTimestamp = nil
        self.autoScrubEmptyFrames = 0
        self.autoScrubEmptyMax = 0
        self.autoScrubEmptyTotal = 0
        self.autoScrubVisibleTotal = 0
        self.autoScrubWorkWorst = 0.0
        let link = CADisplayLink(target: self, selector: #selector(self.autoScrubTick(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
        }
        link.add(to: .main, forMode: .common)
        self.autoScrubLink = link
    }

    private var gridItemCount: Int {
        if self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue {
            return self.photoDataSource?.count ?? 0
        }
        return self.syntheticDataSource.count
    }

    private func countEmptyVisibleCells(_ gridView: MediaGridView) -> (empty: Int, visible: Int) {
        var empty = 0
        var visible = 0
        let bounds = gridView.bounds
        gridView.forEachVisibleCell { index, cell in
            guard let frame = gridView.frameForItem(at: index), frame.intersects(bounds) else {
                return
            }
            visible += 1
            if cell.contents == nil {
                empty += 1
            }
        }
        return (empty, visible)
    }

    private func autoScrubFraction(step: Int, steps: Int) -> CGFloat? {
        let target = DemoViewController.argument("-scrubTo").flatMap(Double.init).map { CGFloat($0) }
        let peak = target ?? 1.0
        let rest: CGFloat = target.map { $0 * 0.5 } ?? 0.0
        if step <= steps {
            return peak * CGFloat(step) / CGFloat(steps)
        } else if step <= 2 * steps {
            let t = CGFloat(step - steps) / CGFloat(steps)
            return peak + (rest - peak) * t
        }
        return nil
    }

    @objc private func autoScrubTick(_ link: CADisplayLink) {
        guard let gridView = self.gridView else {
            return
        }
        let steps = DemoViewController.argument("-scrubSteps").flatMap(Int.init) ?? 120
        let step = self.autoScrubStep
        self.autoScrubStep += 1
        let (empty, visible) = self.countEmptyVisibleCells(gridView)
        if let settleStart = self.autoScrubSettleStart {
            if empty == 0 || link.timestamp - settleStart > 10.0 {
                self.autoScrubLink?.invalidate()
                self.autoScrubLink = nil
                self.autoScrubSettleStart = nil
                let counters = self.instrumentedDataSource?.counters ?? InstrumentedDataSource.Counters()
                print(String(format: "AUTOSCRUB_SETTLE empty=%d visible=%d settle=%.0fms requests=%d cancelled_before_image=%d first_images=%d sync_first_images=%d first_latency_avg=%.1fms first_latency_worst=%.1fms caching_started=%d caching_stopped=%d caching_call_worst=%.2fms request_call_worst=%.2fms", empty, visible, (link.timestamp - settleStart) * 1000.0, counters.requests, counters.cancelledBeforeImage, counters.firstImages, counters.synchronousFirstImages, counters.firstImages > 0 ? counters.firstImageLatencyTotal / Double(counters.firstImages) * 1000.0 : 0.0, counters.firstImageLatencyWorst * 1000.0, counters.cachingStarted, counters.cachingStopped, counters.cachingCallWorst * 1000.0, counters.requestCallWorst * 1000.0))
                fflush(stdout)
            }
            return
        }
        if step > 0 {
            let interval = self.autoScrubLastTimestamp.map { link.timestamp - $0 } ?? 0.0
            if step > 1 {
                if empty > 0 {
                    self.autoScrubEmptyFrames += 1
                }
                self.autoScrubEmptyMax = max(self.autoScrubEmptyMax, empty)
                self.autoScrubEmptyTotal += empty
                self.autoScrubVisibleTotal += visible
            }
            print(String(format: "AUTOSCRUB_FRAME step=%d empty=%d visible=%d dt=%.2fms fast=%d offset=%.1f", step - 1, empty, visible, interval * 1000.0, gridView.isMovingFast ? 1 : 0, gridView.contentOffset))
        } else {
            self.instrumentedDataSource?.resetCounters()
        }
        self.autoScrubLastTimestamp = link.timestamp
        let maximum = max(0.0, gridView.contentHeight - gridView.bounds.height)
        let workStart = CACurrentMediaTime()
        if let fraction = self.autoScrubFraction(step: step, steps: steps) {
            gridView.setContentOffset(maximum * fraction)
        } else {
            let summary = self.frameMonitor.summary
            let measured = max(1, 2 * steps)
            print(String(format: "AUTOSCRUB count=%d level=%d frames=%d dropped=%d worst=%.2fms avg=%.2fms work_worst=%.2fms steps=%d empty_frames=%d/%d empty_max=%d empty_fraction=%.3f (simulator-only)", gridView.contentHeight > 0.0 ? self.gridItemCount : 0, gridView.level.columns, summary.frames, summary.dropped, self.frameMonitor.overallWorst * 1000.0, summary.average * 1000.0, self.autoScrubWorkWorst * 1000.0, 2 * steps, self.autoScrubEmptyFrames, measured, self.autoScrubEmptyMax, self.autoScrubVisibleTotal > 0 ? Double(self.autoScrubEmptyTotal) / Double(self.autoScrubVisibleTotal) : 0.0))
            fflush(stdout)
            self.autoScrubSettleStart = link.timestamp
            return
        }
        self.autoScrubWorkWorst = max(self.autoScrubWorkWorst, CACurrentMediaTime() - workStart)
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
        if let level = self.launchLevel {
            gridView.setLevel(level, animated: false)
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
                        let instrumented = InstrumentedDataSource(base: dataSource)
                        instrumented.forwardsCaching = !ProcessInfo.processInfo.arguments.contains("-noCaching")
                        self.instrumentedDataSource = instrumented
                        self.installGrid(dataSource: instrumented)
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
        self.measureButton.frame = CGRect(x: self.zoomOutButton.frame.maxX + 8.0, y: self.zoomInButton.frame.minY, width: 140.0, height: 32.0)
    }
}
