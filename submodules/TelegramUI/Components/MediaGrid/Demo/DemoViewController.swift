import UIKit
import Photos
import MediaGrid
import MediaGridPhotoLibrary

final class DemoViewController: UIViewController {
    private enum Source: Int {
        case synthetic
        case photoLibrary
    }

    private let syntheticDataSource = SyntheticDataSource()
    private var photoDataSource: MediaGridPhotoLibraryDataSource?
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
    private var autoScrubIndexedEmptyFrames = 0
    private var autoScrubIndexedEmptyMax = 0
    private var autoScrubWorkWorst: CFTimeInterval = 0.0
    private var autoScrubMainTotal: CFTimeInterval = 0.0
    private var autoScrubMainWorst: CFTimeInterval = 0.0
    private var autoScrubMainFrames = 0
    private var autoScrubSettleStart: CFTimeInterval?
    private var autoPinchLink: CADisplayLink?
    private var autoPinchStart: CFTimeInterval?
    private var autoPinchState: MediaGridPinchState?
    private var autoPinchPair: String?
    private var autoPinchCenter: CGPoint = .zero
    private var autoPinchScale: CGFloat = 1.0
    private var autoPinchVelocity: CGFloat = 0.0
    private var autoPinchLastTimestamp: CFTimeInterval?
    private var autoPinchDriveWorst: CFTimeInterval = 0.0
    private var benchmark: PhotoLibraryBenchmark?
    private var rotationDuration: TimeInterval = 0.0
    private var gridNeedsInitialLevel = false
    private var rotationProbe: RotationProbe?
    private let sourceControl = UISegmentedControl(items: ["Synthetic 100k", "Photo Library"])
    private var emptyLink: CADisplayLink?
    private var emptyNow = 0
    private var emptyMax = 0
    private var emptyFrames = 0
    private var autoPinchEmptyFrames = 0
    private var autoPinchEmptyMax = 0
    private var autoPinchIndexedEmptyFrames = 0
    private var autoPinchIndexedEmptyMax = 0
    private var didReportFirstFilledFrame = false
    private var didReportFirstGridFrame = false

    static func makePhotoFetchResult() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        return PHAsset.fetchAssets(with: .image, options: options)
    }

    static func logLine(_ message: String) {
        print(String(format: "%@ since_launch=%.0fms", message, DemoViewController.timeSinceProcessStart() * 1000.0))
        fflush(stdout)
    }

    static func timeSinceProcessStart() -> CFTimeInterval {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else {
            return 0.0
        }
        let start = info.kp_proc.p_un.__p_starttime
        let started = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000.0
        return Date().timeIntervalSince1970 - started
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.sourceControl.selectedSegmentIndex = Source.synthetic.rawValue
        self.sourceControl.addTarget(self, action: #selector(self.sourceChanged), for: .valueChanged)
        self.navigationItem.titleView = self.sourceControl
        self.syntheticDataSource.providesThumbnails = !DemoViewController.disablesThumbnails
        self.syntheticDataSource.onThumbnailsChanged = { [weak self] indices in
            guard let self, self.sourceControl.selectedSegmentIndex == Source.synthetic.rawValue else {
                return
            }
            self.gridView?.thumbnailsDidChange(indices: indices)
        }
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
        self.hudLabel.numberOfLines = 5
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
            guard let self else {
                return
            }
            var text = String(format: "frames %d  dropped %d\nworst(5s) %.1f ms\nempty %d  max %d  frames %d", summary.frames, summary.dropped, summary.worst * 1000.0, self.emptyNow, self.emptyMax, self.emptyFrames)
            if self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue, let dataSource = self.photoDataSource, let filler = dataSource.filler {
                text += String(format: "\nthumbs %d/%d\nno local thumb %d  net %d", filler.filledCount, dataSource.catalogCount, filler.unavailableCount, filler.networkFills)
            }
            self.hudLabel.text = text
        }
        self.frameMonitor.start()
        let emptyLink = CADisplayLink(target: DisplayLinkTarget(owner: self), selector: #selector(DisplayLinkTarget.tick(_:)))
        if #available(iOS 15.0, *) {
            emptyLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
        }
        emptyLink.add(to: .main, forMode: .common)
        self.emptyLink = emptyLink
    }

    deinit {
        self.emptyLink?.invalidate()
    }

    private let logsFrames = ProcessInfo.processInfo.arguments.contains("-frameLog")
    private var frameLogLastTimestamp: CFTimeInterval?
    private var frameLogCount = 0

    fileprivate func emptyTick(_ link: CADisplayLink) {
        #if DEBUG
        guard let gridView = self.gridView else {
            return
        }
        let (empty, visible) = gridView.debugEmptyVisibleCellCount()
        if self.logsFrames {
            let filledEmpty = empty > 0 ? self.countIndexedEmptyCells(gridView) : 0
            let interval = self.frameLogLastTimestamp.map { link.timestamp - $0 } ?? 0.0
            self.frameLogLastTimestamp = link.timestamp
            self.frameLogCount += 1
            var unfilled = -1
            if self.frameLogCount % 15 == 0, let dataSource = self.photoDataSource, self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue {
                unfilled = gridView.debugEmptyVisibleCellCount(counting: { _ in true }, treatingAsEmpty: { !dataSource.hasStoredThumbnail(at: $0) }).empty
            }
            print(String(format: "FRAME t=%.4f dt=%.2f expected=%.2f level=%d transition=%d empty=%d filled_empty=%d visible=%d fast=%d offset=%.1f unfilled=%d", link.timestamp, interval * 1000.0, (link.targetTimestamp - link.timestamp) * 1000.0, gridView.level.columns, gridView.debugIsZooming ? 1 : 0, empty, filledEmpty, visible, gridView.isMovingFast ? 1 : 0, gridView.contentOffset, unfilled))
        }
        if !self.didReportFirstGridFrame, visible > 0, self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue {
            self.didReportFirstGridFrame = true
            print(String(format: "FIRST_GRID_FRAME since_launch=%.0fms visible=%d empty=%d launch_wait=%.2fms requests=%d", DemoViewController.timeSinceProcessStart() * 1000.0, visible, empty, (gridView.launchImageWaitDuration ?? 0.0) * 1000.0, self.instrumentedDataSource?.counters.requests ?? -1))
            fflush(stdout)
        }
        if !self.didReportFirstFilledFrame, visible > 0, empty == 0, self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue {
            self.didReportFirstFilledFrame = true
            print(String(format: "FIRST_FILLED_FRAME since_launch=%.0fms visible=%d decoded_pages=%d", DemoViewController.timeSinceProcessStart() * 1000.0, visible, self.photoDataSource?.store.decodedPageCount ?? 0))
            fflush(stdout)
        }
        self.emptyNow = empty
        self.emptyMax = max(self.emptyMax, empty)
        if empty > 0 {
            self.emptyFrames += 1
        }
        if self.autoPinchLink != nil {
            self.autoPinchEmptyMax = max(self.autoPinchEmptyMax, empty)
            if empty > 0 {
                self.autoPinchEmptyFrames += 1
            }
            let indexedEmpty = empty > 0 ? self.countIndexedEmptyCells(gridView) : 0
            self.autoPinchIndexedEmptyMax = max(self.autoPinchIndexedEmptyMax, indexedEmpty)
            if indexedEmpty > 0 {
                self.autoPinchIndexedEmptyFrames += 1
            }
        }
        #endif
    }

    private static let disablesThumbnails = ProcessInfo.processInfo.arguments.contains("-noThumbnails")

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
        let benchmark = PhotoLibraryBenchmark(fetchResult: DemoViewController.makePhotoFetchResult())
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
        if ProcessInfo.processInfo.arguments.contains("-fillLog") {
            self.logFillProgress(started: CACurrentMediaTime())
        }
        if ProcessInfo.processInfo.arguments.contains("-waitForFill") {
            if DemoViewController.argument("-source") == "photos" {
                self.waitForFill(started: CACurrentMediaTime())
                return
            }
            print("WAITFORFILL skipped: -waitForFill needs -source photos")
            fflush(stdout)
        }
        self.startAutomation()
    }

    private func logFillProgress(started: CFTimeInterval) {
        if let dataSource = self.photoDataSource, let filler = dataSource.filler {
            print(String(format: "FILL_PROGRESS t=%.0fs filled=%d/%d unavailable=%d missing=%d in_flight=%d net_in_flight=%d net_fills=%d harvests=%d retry_entries=%d launch_released=%d", CACurrentMediaTime() - started, filler.filledCount, dataSource.catalogCount, filler.unavailableCount, filler.missingCount, filler.inFlightCount, filler.networkInFlightCount, filler.networkFills, dataSource.harvests, filler.retryEntryCount, filler.launchRetriesReleased))
            fflush(stdout)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.logFillProgress(started: started)
        }
    }

    private func waitForFill(started: CFTimeInterval) {
        guard let dataSource = self.photoDataSource, let filler = dataSource.filler, filler.isComplete else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.waitForFill(started: started)
            }
            return
        }
        dataSource.store.flush { [weak self] in
            guard let self else {
                return
            }
            let directory = MediaGridPhotoLibraryServices.defaultDirectory
            let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            var bytes: UInt64 = 0
            var pageFiles = 0
            for name in names {
                let attributes = try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(name).path)
                bytes += (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
                if name != "index.bin" {
                    pageFiles += 1
                }
            }
            print(String(format: "WAITFORFILL ready after=%.2fs filled=%d unavailable=%d total=%d fill_time=%@ store_bytes=%llu files=%d decoded_pages=%d", CACurrentMediaTime() - started, filler.filledCount, filler.unavailableCount, dataSource.catalogCount, dataSource.fillDuration.map { String(format: "%.2fs", $0) } ?? "-", bytes, pageFiles, dataSource.store.decodedPageCount))
            fflush(stdout)
            self.startAutomation()
        }
    }

    private func runSharpProbe(fractions: [CGFloat]) {
        #if DEBUG
        guard let fraction = fractions.first, let gridView = self.gridView else {
            print("SHARP_PROBE done")
            fflush(stdout)
            return
        }
        gridView.setContentOffset(fraction * max(0.0, gridView.contentHeight - gridView.bounds.height))
        let start = CACurrentMediaTime()
        func poll() {
            let (final, visible) = gridView.debugVisibleFinalImageCount()
            let elapsed = CACurrentMediaTime() - start
            if (visible > 0 && final == visible) || elapsed > 20.0 {
                print(String(format: "SHARP_PROBE fraction=%.2f time=%.0fms final=%d visible=%d net_in_flight=%d", fraction, elapsed * 1000.0, final, visible, self.photoDataSource?.filler?.networkInFlightCount ?? 0))
                fflush(stdout)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.runSharpProbe(fractions: Array(fractions.dropFirst()))
                }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.008) {
                poll()
            }
        }
        poll()
        #endif
    }

    private func startAutomation() {
        if let fraction = DemoViewController.argument("-startAt").flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let gridView = self?.gridView else {
                    return
                }
                gridView.setContentOffset(CGFloat(fraction) * max(0.0, gridView.contentHeight - gridView.bounds.height))
                print("STARTAT fraction=\(fraction) top=\(gridView.topVisibleIndex ?? -1)")
                fflush(stdout)
            }
        }
        if let delay = DemoViewController.argument("-sharpProbe").flatMap(Double.init) {
            if ProcessInfo.processInfo.arguments.contains("-noNetworkLane") {
                self.photoDataSource?.filler?.isNetworkLaneEnabled = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                let fractions = DemoViewController.argument("-probeFractions").map { $0.split(separator: ",").compactMap { Double($0).map { CGFloat($0) } } } ?? [0.1, 0.6, 0.3, 0.8, 0.2, 0.7, 0.15, 0.9]
                self?.runSharpProbe(fractions: fractions)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-autoScrub") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startAutoScrub()
            }
        }
        if let fraction = DemoViewController.argument("-driftAt").flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.drift(at: CGFloat(fraction), step: 0)
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
        if ProcessInfo.processInfo.arguments.contains("-autoRotate") {
            let delay = DemoViewController.argument("-rotateDelay").flatMap(Double.init) ?? 3.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.requestOrientation(landscape: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.requestOrientation(landscape: false)
                }
            }
        }
    }

    private func requestOrientation(landscape: Bool) {
        guard let scene = self.view.window?.windowScene else {
            return
        }
        if let fraction = DemoViewController.argument("-rotateAt").flatMap(Double.init), landscape, let gridView = self.gridView {
            gridView.setContentOffset(CGFloat(fraction) * max(0.0, gridView.contentHeight - gridView.bounds.height))
        }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscape ? .landscapeRight : .portrait)) { error in
            print("rotate error \(error)")
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.rotationDuration = coordinator.transitionDuration
        let probe = RotationProbe(level: self.gridView?.level, top: self.gridView?.topVisibleIndex, requestCount: { [weak self] in
            return self?.instrumentedDataSource?.counters.requests ?? 0
        })
        self.rotationProbe = probe
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil, completion: { [weak self] _ in
            guard let self else {
                return
            }
            self.rotationDuration = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak probe] in
                guard let self, let probe, self.rotationProbe === probe else {
                    return
                }
                self.rotationProbe = nil
                probe.finish(level: self.gridView?.level, top: self.gridView?.topVisibleIndex, firstRow: self.firstRowRange())
            }
        })
    }

    private func firstRowRange() -> String {
        guard let gridView = self.gridView, let top = gridView.topVisibleIndex, let frame = gridView.frameForItem(at: top) else {
            return "-"
        }
        var last = top
        while let next = gridView.frameForItem(at: last + 1), abs(next.minY - frame.minY) < 0.5 {
            last += 1
        }
        return "\(top)...\(last) y=\(String(format: "%.1f", frame.minY))"
    }

    private func startAutoPinch() {
        #if DEBUG
        guard self.autoPinchLink == nil, let gridView = self.gridView else {
            return
        }
        gridView.layoutIfNeeded()
        gridView.setContentOffset(gridView.contentHeight * 0.4)
        self.autoPinchCenter = CGPoint(x: gridView.bounds.midX, y: gridView.bounds.midY)
        self.autoPinchStart = nil
        self.autoPinchScale = 1.0
        self.autoPinchLastTimestamp = nil
        self.autoPinchPair = nil
        self.autoPinchState = MediaGridPinchState(startLevel: gridView.level, anchor: MediaGridZoomAnchor(index: 0, pointInView: self.autoPinchCenter))
        let delay = DemoViewController.argument("-pinchDelay").flatMap(Double.init) ?? 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.autoPinchLink == nil else {
                return
            }
            let link = CADisplayLink(target: self, selector: #selector(self.autoPinchTick(_:)))
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
            }
            link.add(to: .main, forMode: .common)
            self.autoPinchLink = link
        }
        #endif
    }

    private func reportAutoPinchPair() {
        if let pair = self.autoPinchPair {
            let summary = self.frameMonitor.summary
            print(String(format: "AUTOPINCH pair=%@ frames=%d dropped=%d worst=%.2fms avg=%.2fms drive_worst=%.2fms empty_frames=%d empty_max=%d indexed_empty_frames=%d indexed_empty_max=%d (simulator-only)", pair, summary.frames, summary.dropped, self.frameMonitor.overallWorst * 1000.0, summary.average * 1000.0, self.autoPinchDriveWorst * 1000.0, self.autoPinchEmptyFrames, self.autoPinchEmptyMax, self.autoPinchIndexedEmptyFrames, self.autoPinchIndexedEmptyMax))
            fflush(stdout)
        }
        self.frameMonitor.reset()
        self.autoPinchDriveWorst = 0.0
        self.autoPinchEmptyFrames = 0
        self.autoPinchEmptyMax = 0
        self.autoPinchIndexedEmptyFrames = 0
        self.autoPinchIndexedEmptyMax = 0
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
            gridView.debugDrivePinch(.began, center: self.autoPinchCenter, scale: 1.0, velocity: 0.0)
            return
        }
        let exponent: CGFloat
        if elapsed < outDuration {
            exponent = deepest * CGFloat(elapsed / outDuration)
        } else if elapsed < outDuration + backDuration {
            exponent = deepest * CGFloat(1.0 - (elapsed - outDuration) / backDuration)
        } else {
            self.reportAutoPinchPair()
            gridView.debugDrivePinch(.ended, center: self.autoPinchCenter, scale: 1.0, velocity: 0.0)
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
        gridView.debugDrivePinch(.changed, center: self.autoPinchCenter, scale: scale, velocity: self.autoPinchVelocity)
        CATransaction.flush()
        self.autoPinchDriveWorst = max(self.autoPinchDriveWorst, CACurrentMediaTime() - driveStart)
        #endif
    }

    private func drift(at fraction: CGFloat, step: Int) {
        guard let gridView = self.gridView, step <= 8 else {
            return
        }
        let scale = gridView.traitCollection.displayScale
        let base = (fraction * max(0.0, gridView.contentHeight - gridView.bounds.height) * scale).rounded() / scale
        gridView.setContentOffset(base + CGFloat(step) / scale)
        print(String(format: "DRIFT step=%d offset=%.4f height=%.1f top=%d", step, gridView.contentOffset, gridView.contentHeight, gridView.topVisibleIndex ?? -1))
        fflush(stdout)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.drift(at: fraction, step: step + 1)
        }
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
            let enumerated = DemoViewController.makePhotoFetchResult()
            var enumerateSum = 0.0
            let enumerateStart = CACurrentMediaTime()
            enumerated.enumerateObjects { asset, _, _ in
                enumerateSum += Double(asset.pixelWidth) / Double(max(1, asset.pixelHeight))
            }
            let enumerateTime = CACurrentMediaTime() - enumerateStart

            let indexed = DemoViewController.makePhotoFetchResult()
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
        self.emptyMax = 0
        self.emptyFrames = 0
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
        self.autoScrubIndexedEmptyFrames = 0
        self.autoScrubIndexedEmptyMax = 0
        self.autoScrubWorkWorst = 0.0
        self.autoScrubMainTotal = 0.0
        self.autoScrubMainWorst = 0.0
        self.autoScrubMainFrames = 0
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
        #if DEBUG
        return gridView.debugEmptyVisibleCellCount()
        #else
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
        #endif
    }

    private func countIndexedEmptyCells(_ gridView: MediaGridView) -> Int {
        #if DEBUG
        guard self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue, let dataSource = self.photoDataSource else {
            return gridView.debugEmptyVisibleCellCount().empty
        }
        return gridView.debugEmptyVisibleCellCount(counting: { dataSource.hasStoredThumbnail(at: $0) }).empty
        #else
        return 0
        #endif
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
            let indexedEmpty = self.countIndexedEmptyCells(gridView)
            if step > 1 {
                if empty > 0 {
                    self.autoScrubEmptyFrames += 1
                }
                if indexedEmpty > 0 {
                    self.autoScrubIndexedEmptyFrames += 1
                }
                self.autoScrubIndexedEmptyMax = max(self.autoScrubIndexedEmptyMax, indexedEmpty)
                self.autoScrubEmptyMax = max(self.autoScrubEmptyMax, empty)
                self.autoScrubEmptyTotal += empty
                self.autoScrubVisibleTotal += visible
            }
            print(String(format: "AUTOSCRUB_FRAME step=%d empty=%d indexed_empty=%d visible=%d dt=%.2fms fast=%d offset=%.1f", step - 1, empty, indexedEmpty, visible, interval * 1000.0, gridView.isMovingFast ? 1 : 0, gridView.contentOffset))
        } else {
            self.instrumentedDataSource?.resetCounters()
        }
        self.autoScrubLastTimestamp = link.timestamp
        let maximum = max(0.0, gridView.contentHeight - gridView.bounds.height)
        let workStart = CACurrentMediaTime()
        if let fraction = self.autoScrubFraction(step: step, steps: steps) {
            gridView.setContentOffset(maximum * fraction)
            self.autoScrubWorkWorst = max(self.autoScrubWorkWorst, CACurrentMediaTime() - workStart)
            if ProcessInfo.processInfo.arguments.contains("-mainProbe") {
                CATransaction.flush()
                let main = CACurrentMediaTime() - workStart
                self.autoScrubMainTotal += main
                self.autoScrubMainWorst = max(self.autoScrubMainWorst, main)
                self.autoScrubMainFrames += 1
            }
        } else {
            let summary = self.frameMonitor.summary
            let measured = max(1, 2 * steps)
            print(String(format: "AUTOSCRUB count=%d level=%d frames=%d dropped=%d worst=%.2fms avg=%.2fms work_worst=%.2fms steps=%d empty_frames=%d/%d empty_max=%d empty_fraction=%.3f indexed_empty_frames=%d indexed_empty_max=%d main_avg=%.2fms main_worst=%.2fms (simulator-only)", gridView.contentHeight > 0.0 ? self.gridItemCount : 0, gridView.level.columns, summary.frames, summary.dropped, self.frameMonitor.overallWorst * 1000.0, summary.average * 1000.0, self.autoScrubWorkWorst * 1000.0, 2 * steps, self.autoScrubEmptyFrames, measured, self.autoScrubEmptyMax, self.autoScrubVisibleTotal > 0 ? Double(self.autoScrubEmptyTotal) / Double(self.autoScrubVisibleTotal) : 0.0, self.autoScrubIndexedEmptyFrames, self.autoScrubIndexedEmptyMax, self.autoScrubMainFrames > 0 ? self.autoScrubMainTotal / Double(self.autoScrubMainFrames) * 1000.0 : 0.0, self.autoScrubMainWorst * 1000.0))
            if let dataSource = self.photoDataSource, let counters = self.instrumentedDataSource?.counters, self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue {
                print(String(format: "AUTOSCRUB_PREPARE calls=%d avg=%.3fms worst=%.3fms in_flight=%d", counters.prepareCalls, counters.prepareCalls > 0 ? counters.prepareCallTotal / Double(counters.prepareCalls) * 1000.0 : 0.0, counters.prepareCallWorst * 1000.0, dataSource.filler?.inFlightCount ?? 0))
            }
            fflush(stdout)
            self.autoScrubSettleStart = link.timestamp
            return
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
        gridView.onMovingFastChanged = { [weak self] isMovingFast in
            guard let self, self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue else {
                return
            }
            self.photoDataSource?.filler?.isMovingFast = isMovingFast
        }
        if let level = self.launchLevel {
            gridView.setLevel(level, animated: false)
        } else {
            self.gridNeedsInitialLevel = true
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

    private func photoLibraryChanged(_ changes: MediaGridChanges?) {
        guard let gridView = self.gridView else {
            return
        }
        print("LIBRARY_CHANGE removed=\(changes?.removed.count ?? -1) inserted=\(changes?.inserted.count ?? -1) changed=\(changes?.changed.count ?? -1)")
        fflush(stdout)
        if let changes {
            self.selectedIndices = Set(self.selectedIndices.compactMap { changes.newIndex(forOld: $0) })
            gridView.apply(changes)
        } else {
            self.selectedIndices = []
            gridView.reloadData()
        }
    }

    @objc private func sourceChanged() {
        switch Source(rawValue: self.sourceControl.selectedSegmentIndex) ?? .synthetic {
        case .synthetic:
            self.photoDataSource?.onChange = nil
            self.photoDataSource?.filler?.isMovingFast = false
            self.installGrid(dataSource: self.syntheticDataSource)
        case .photoLibrary:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    guard let self, self.sourceControl.selectedSegmentIndex == Source.photoLibrary.rawValue else {
                        return
                    }
                    if status == .authorized || status == .limited {
                        let services = MediaGridPhotoLibraryServices.shared
                        let fetchResult = DemoViewController.makePhotoFetchResult()
                        let launch = ProcessInfo.processInfo.arguments.contains("-noLaunchCache") ? nil : services.makeLaunchMatch(fetchResult: fetchResult, reversed: true)
                        services.filler.onLog = { message in
                            DemoViewController.logLine(message)
                        }
                        let dataSource = MediaGridPhotoLibraryDataSource(fetchResult: fetchResult, reversed: true, store: services.store, launch: launch, filler: services.filler, snapshotURL: services.snapshotURL)
                        dataSource.onLog = { message in
                            DemoViewController.logLine(message)
                        }
                        dataSource.launchKeeper?.onRefresh = { written in
                            print(String(format: "LAUNCH refresh written=%d since_launch=%.0fms", written ? 1 : 0, DemoViewController.timeSinceProcessStart() * 1000.0))
                            fflush(stdout)
                        }
                        self.photoDataSource?.onChange = nil
                        self.photoDataSource = dataSource
                        dataSource.onChange = { [weak self] changes in
                            self?.photoLibraryChanged(changes)
                        }
                        dataSource.onThumbnailsChanged = { [weak self, weak dataSource] indices in
                            guard let self, let dataSource, self.photoDataSource === dataSource else {
                                return
                            }
                            self.gridView?.thumbnailsDidChange(indices: indices)
                        }
                        let instrumented = InstrumentedDataSource(base: dataSource)
                        instrumented.forwardsCaching = !ProcessInfo.processInfo.arguments.contains("-noCaching")
                        if DemoViewController.disablesThumbnails {
                            instrumented.providesThumbnails = false
                            dataSource.filler?.isNetworkLaneEnabled = false
                        }
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
        let isLandscape = self.traitCollection.userInterfaceIdiom == .phone && self.view.bounds.width > self.view.bounds.height
        if self.gridNeedsInitialLevel, self.view.bounds.width > 0.0 {
            self.gridNeedsInitialLevel = false
            gridView.setLevel(MediaGridLevel.defaultLevel(isLandscape: isLandscape), animated: false)
        }
        self.bannerView.text = "Banner placeholder"
        self.bannerView.textAlignment = .center
        self.bannerView.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.8)
        if self.bannerView.superview == nil {
            self.view.insertSubview(self.bannerView, aboveSubview: gridView)
        }
        self.bannerView.frame = CGRect(x: 0.0, y: self.view.safeAreaInsets.top, width: self.view.bounds.width, height: 44.0)
        var geometryInsets = gridView.geometryInsets
        geometryInsets.top = self.view.safeAreaInsets.top + 44.0
        gridView.geometryInsets = geometryInsets
        let insets = self.view.safeAreaInsets
        let start = CACurrentMediaTime()
        gridView.updateLayout(size: self.view.bounds.size, safeInsets: insets, isLandscape: isLandscape, transition: self.rotationDuration)
        self.rotationProbe?.noteUpdate(CACurrentMediaTime() - start)
        self.scrubber.frame = CGRect(x: self.view.bounds.width - 220.0, y: insets.top, width: 220.0, height: self.view.bounds.height - insets.top - insets.bottom)
        self.hudLabel.frame = CGRect(x: 8.0, y: insets.top + 8.0, width: 170.0, height: 74.0)
        self.resetButton.frame = CGRect(x: 8.0, y: self.hudLabel.frame.maxY + 4.0, width: 60.0, height: 28.0)
        self.zoomInButton.frame = CGRect(x: 8.0, y: self.view.bounds.height - insets.bottom - 40.0, width: 84.0, height: 32.0)
        self.zoomOutButton.frame = CGRect(x: self.zoomInButton.frame.maxX + 8.0, y: self.zoomInButton.frame.minY, width: 84.0, height: 32.0)
        self.measureButton.frame = CGRect(x: self.zoomOutButton.frame.maxX + 8.0, y: self.zoomInButton.frame.minY, width: 140.0, height: 32.0)
    }
}

private final class DisplayLinkTarget: NSObject {
    private weak var owner: DemoViewController?

    init(owner: DemoViewController) {
        self.owner = owner
    }

    @objc func tick(_ link: CADisplayLink) {
        self.owner?.emptyTick(link)
    }
}

private final class RotationProbe {
    private let startLevel: MediaGridLevel?
    private let startTop: Int?
    private var link: CADisplayLink?
    private var last: CFTimeInterval?
    private var intervals: [Double] = []
    private var timestamps: [CFTimeInterval] = []
    private var updates: [Double] = []
    private var updateTime: CFTimeInterval?
    private let turnStart = CACurrentMediaTime()
    private var turnDuration: Double?
    private let requestCount: () -> Int
    private let startRequests: Int
    private var turnRequests: Int?

    init(level: MediaGridLevel?, top: Int?, requestCount: @escaping () -> Int) {
        self.startLevel = level
        self.startTop = top
        self.requestCount = requestCount
        self.startRequests = requestCount()
        let link = CADisplayLink(target: self, selector: #selector(self.tick(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
        }
        link.add(to: .main, forMode: .common)
        self.link = link
        let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, false, CFIndex.max) { [weak self] _, _ in
            guard let self else {
                return
            }
            if self.turnDuration == nil {
                self.turnDuration = (CACurrentMediaTime() - self.turnStart) * 1000.0
                self.turnRequests = self.requestCount() - self.startRequests
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    func noteUpdate(_ duration: CFTimeInterval) {
        self.updates.append(duration * 1000.0)
        if self.updateTime == nil {
            self.updateTime = CACurrentMediaTime() - duration
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        if let last = self.last {
            self.intervals.append((link.timestamp - last) * 1000.0)
            self.timestamps.append(link.timestamp)
        }
        self.last = link.timestamp
    }

    func finish(level: MediaGridLevel?, top: Int?, firstRow: String) {
        self.link?.invalidate()
        self.link = nil
        let sorted = self.intervals.sorted()
        let worst = sorted.last ?? 0.0
        let median = sorted.isEmpty ? 0.0 : sorted[sorted.count / 2]
        let over = self.intervals.filter { $0 > median * 1.5 }.count
        var slow = ""
        if let updateTime = self.updateTime {
            for (index, interval) in self.intervals.enumerated() where interval > median * 1.5 {
                slow += String(format: " slow %.1fms@%+.0fms", interval, (self.timestamps[index] - updateTime) * 1000.0)
            }
        }
        if let turn = self.turnDuration {
            slow += String(format: " turn %.1fms turn_requests %d", turn, self.turnRequests ?? -1)
        }
        let updates = self.updates.map { String(format: "%.2f", $0) }.joined(separator: ",")
        print(String(format: "rotate %@ -> %@ top %@ -> %@ firstRow %@ updateLayout ms [%@] frames %d median %.2f worst %.2f dropped %d%@", self.startLevel.map { "\($0.rawValue)" } ?? "-", level.map { "\($0.rawValue)" } ?? "-", self.startTop.map { "\($0)" } ?? "-", top.map { "\($0)" } ?? "-", firstRow, updates, self.intervals.count, median, worst, over, slow))
    }
}
