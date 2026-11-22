import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import Photos
import SwiftSignalKit
import MediaEditor
import ChatMediaSend

public protocol ChatMediaEditorItemsSource: AnyObject {
    var count: Int { get }
    func item(at index: Int) -> ChatMediaEditorItem
    func index(of uniqueId: String) -> Int?
}

public func chatMediaEditorMirroredIndex(_ index: Int, count: Int, reversed: Bool) -> Int {
    return reversed ? count - 1 - index : index
}

public final class ChatMediaEditorFetchResultSource: ChatMediaEditorItemsSource {
    private let assetCount: Int
    private let reversed: Bool
    private let asset: (Int) -> PHAsset
    private let indexOfIdentifier: (String) -> Int?

    public convenience init(fetchResult: PHFetchResult<PHAsset>, reversed: Bool) {
        self.init(count: fetchResult.count, reversed: reversed, asset: { index in
            return fetchResult.object(at: index)
        }, indexOfIdentifier: { identifier in
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
                return nil
            }
            let index = fetchResult.index(of: asset)
            return index == NSNotFound ? nil : index
        })
    }

    public init(count: Int, reversed: Bool, asset: @escaping (Int) -> PHAsset, indexOfIdentifier: @escaping (String) -> Int?) {
        self.assetCount = count
        self.reversed = reversed
        self.asset = asset
        self.indexOfIdentifier = indexOfIdentifier
    }

    public var count: Int {
        return self.assetCount
    }

    public func item(at index: Int) -> ChatMediaEditorItem {
        let asset = self.asset(chatMediaEditorMirroredIndex(index, count: self.assetCount, reversed: self.reversed))
        return chatMediaEditorAssetItem(uniqueId: asset.localIdentifier, asset: asset)
    }

    public func index(of uniqueId: String) -> Int? {
        guard let rawIndex = self.indexOfIdentifier(uniqueId), rawIndex >= 0, rawIndex < self.assetCount else {
            return nil
        }
        return chatMediaEditorMirroredIndex(rawIndex, count: self.assetCount, reversed: self.reversed)
    }
}

public final class ChatMediaEditorListSource: ChatMediaEditorItemsSource {
    private let items: [ChatMediaEditorItem]

    public init(items: [ChatMediaEditorItem]) {
        self.items = items
    }

    public var count: Int {
        return self.items.count
    }

    public func item(at index: Int) -> ChatMediaEditorItem {
        return self.items[index]
    }

    public func index(of uniqueId: String) -> Int? {
        return self.items.firstIndex(where: { $0.uniqueId == uniqueId })
    }
}

public protocol ChatMediaEditorAppendableItemsSource: ChatMediaEditorItemsSource {
    func addAppendListener(_ f: @escaping () -> Void) -> Disposable
}

public final class ChatMediaEditorMutableListSource: ChatMediaEditorAppendableItemsSource {
    private var items: [ChatMediaEditorItem] = []
    private var indices: [String: Int] = [:]
    private let listeners = Bag<() -> Void>()

    public init(items: [ChatMediaEditorItem]) {
        for item in items {
            let _ = self.insert(item)
        }
    }

    public var count: Int {
        return self.items.count
    }

    public func item(at index: Int) -> ChatMediaEditorItem {
        return self.items[index]
    }

    public func index(of uniqueId: String) -> Int? {
        return self.indices[uniqueId]
    }

    @discardableResult
    public func append(_ item: ChatMediaEditorItem) -> Bool {
        guard self.insert(item) else {
            return false
        }
        for f in self.listeners.copyItems() {
            f()
        }
        return true
    }

    public func addAppendListener(_ f: @escaping () -> Void) -> Disposable {
        let index = self.listeners.add(f)
        return ActionDisposable { [weak self] in
            self?.listeners.remove(index)
        }
    }

    private func insert(_ item: ChatMediaEditorItem) -> Bool {
        guard self.indices[item.uniqueId] == nil else {
            return false
        }
        self.indices[item.uniqueId] = self.items.count
        self.items.append(item)
        return true
    }
}

public let chatMediaEditorPagerPageSpacing: CGFloat = 40.0

public func chatMediaEditorPagerLayout(width: CGFloat, height: CGFloat, index: Int, offset: CGFloat, count: Int) -> [(index: Int, frame: CGRect)] {
    guard count > 0, width > 0.0 else {
        return []
    }
    let pageWidth = width + chatMediaEditorPagerPageSpacing
    let inset = chatMediaEditorPagerPageSpacing / 2.0
    var indices = Set<Int>()
    for i in (index - 1) ... (index + 1) where i >= 0 && i < count {
        indices.insert(i)
    }
    let lowerBound = Int(floor(offset / pageWidth)) - 1
    let upperBound = Int(ceil((offset + pageWidth) / pageWidth))
    if lowerBound <= upperBound {
        for i in lowerBound ... upperBound where i >= 0 && i < count {
            let minX = CGFloat(i) * pageWidth + inset
            if minX < offset + pageWidth && minX + width > offset {
                indices.insert(i)
            }
        }
    }
    return indices.sorted().map { i in
        return (index: i, frame: CGRect(x: CGFloat(i) * pageWidth + inset, y: 0.0, width: width, height: height))
    }
}

public func chatMediaEditorPagerOffset(index: Int, width: CGFloat) -> CGFloat {
    return (width + chatMediaEditorPagerPageSpacing) * CGFloat(index)
}

public let chatMediaEditorPagerParallaxFactor: CGFloat = 0.16

public func chatMediaEditorPagerParallaxOffset(pageFrame: CGRect, contentOffset: CGFloat) -> CGFloat {
    let center = pageFrame.minX - chatMediaEditorPagerPageSpacing / 2.0 - contentOffset
    return -center * chatMediaEditorPagerParallaxFactor
}

public func chatMediaEditorPagerSettledIndex(offset: CGFloat, width: CGFloat, count: Int) -> Int {
    guard count > 0, width > 0.0 else {
        return 0
    }
    let pageWidth = width + chatMediaEditorPagerPageSpacing
    let index = Int((offset / pageWidth).rounded())
    return max(0, min(count - 1, index))
}

public struct ChatMediaEditorPageRestore {
    public let item: ChatMediaEditorItem
    public let values: MediaEditorValues?
    public let lockedAspectRatio: CGFloat?
}

public func chatMediaEditorShouldSaveItem(hasEntry: Bool, values: MediaEditorValues, baselineQualityPreset: MediaQualityPreset?) -> Bool {
    return hasEntry || chatMediaEditorValuesAreEdited(values, baselineQualityPreset: baselineQualityPreset)
}

public final class ChatMediaEditorPageModel {
    public let itemsSource: ChatMediaEditorItemsSource
    public let store: ChatMediaEditorItemStore
    public private(set) var currentIndex: Int

    public init(itemsSource: ChatMediaEditorItemsSource, store: ChatMediaEditorItemStore, initialIndex: Int) {
        self.itemsSource = itemsSource
        self.store = store
        self.currentIndex = max(0, min(itemsSource.count - 1, initialIndex))
    }

    public var currentItem: ChatMediaEditorItem {
        return self.itemsSource.item(at: self.currentIndex)
    }

    public func restore() -> ChatMediaEditorPageRestore {
        let item = self.currentItem
        let entry = self.store.entry(for: item.uniqueId)
        return ChatMediaEditorPageRestore(item: item, values: entry?.values, lockedAspectRatio: entry?.lockedAspectRatio)
    }

    @discardableResult
    public func save(values: MediaEditorValues, lockedAspectRatio: CGFloat?) -> Bool {
        let uniqueId = self.currentItem.uniqueId
        guard chatMediaEditorShouldSaveItem(hasEntry: self.store.entry(for: uniqueId) != nil, values: values, baselineQualityPreset: self.store.qualityPresetBaseline(for: uniqueId)) else {
            return false
        }
        self.store.update(uniqueId) { entry in
            if entry.values != values || !chatMediaEditorValuesHaveVisualEdits(values) {
                entry.thumbnail = nil
            }
            entry.values = values
            entry.lockedAspectRatio = lockedAspectRatio
        }
        return true
    }

    public func switchPage(to index: Int, savingValues values: MediaEditorValues, lockedAspectRatio: CGFloat?) -> ChatMediaEditorPageRestore? {
        guard index != self.currentIndex, index >= 0, index < self.itemsSource.count else {
            return nil
        }
        self.save(values: values, lockedAspectRatio: lockedAspectRatio)
        self.currentIndex = index
        return self.restore()
    }

    public func storedThumbnail(at index: Int) -> UIImage? {
        guard index >= 0, index < self.itemsSource.count else {
            return nil
        }
        return self.store.entry(for: self.itemsSource.item(at: index).uniqueId)?.thumbnail
    }

    @discardableResult
    public func storeThumbnail(_ thumbnail: UIImage, uniqueId: String, values: MediaEditorValues) -> Bool {
        guard let entry = self.store.entry(for: uniqueId), entry.values == values, chatMediaEditorValuesHaveVisualEdits(values) else {
            return false
        }
        self.store.update(uniqueId) { entry in
            entry.thumbnail = thumbnail
        }
        return true
    }
}

public enum ChatMediaEditorSwipeDownDecision: Equatable {
    case undecided
    case begin
    case fail
}

public func chatMediaEditorSwipeDownDecision(translation: CGPoint) -> ChatMediaEditorSwipeDownDecision {
    if abs(translation.x) >= 10.0 {
        return .fail
    }
    if abs(translation.y) >= 12.0 {
        return .begin
    }
    return .undecided
}

public func chatMediaEditorSwipeDownProgress(translation: CGFloat) -> CGFloat {
    return max(0.0, min(1.0, abs(translation) / 150.0))
}

public func chatMediaEditorSwipeDownBackgroundAlpha(translation: CGFloat) -> CGFloat {
    return 1.0 - max(0.0, min(1.0, chatMediaEditorSwipeDownProgress(translation: translation) * 4.0))
}

public func chatMediaEditorSwipeDownShouldDismiss(translation: CGFloat, velocity: CGFloat) -> Bool {
    return abs(velocity) >= 700.0 || abs(translation) >= 128.0
}

public func chatMediaEditorSwipeDownDismissDirection(translation: CGFloat, velocity: CGFloat) -> CGFloat {
    if abs(velocity) >= 700.0 {
        return velocity < 0.0 ? -1.0 : 1.0
    }
    return translation < 0.0 ? -1.0 : 1.0
}

public func chatMediaEditorCanOpenTool(isToolActive: Bool, isSending: Bool, isDismissing: Bool, isPagerMoving: Bool) -> Bool {
    return !isToolActive && !isSending && !isDismissing && !isPagerMoving
}

public let chatMediaEditorPhotoMinZoomScale: CGFloat = 0.05
public let chatMediaEditorDoubleTapZoomDuration: Double = 0.4 * 0.6
public let chatMediaEditorZoomSpringBackDuration: Double = 0.4 * 0.5

public func chatMediaEditorZoomTargetOffset(viewportSize: CGSize, mediaFrame: CGRect, zoomScale: CGFloat, focus: CGPoint) -> CGPoint {
    let insets = chatMediaEditorZoomContentInsets(viewportSize: viewportSize, mediaFrame: mediaFrame, zoomScale: zoomScale)
    let desired = CGPoint(x: focus.x * zoomScale - viewportSize.width / 2.0, y: focus.y * zoomScale - viewportSize.height / 2.0)
    let minX = -insets.left
    let maxX = max(minX, viewportSize.width * zoomScale + insets.right - viewportSize.width)
    let minY = -insets.top
    let maxY = max(minY, viewportSize.height * zoomScale + insets.bottom - viewportSize.height)
    return CGPoint(x: max(minX, min(maxX, desired.x)), y: max(minY, min(maxY, desired.y)))
}

final class ChatMediaEditorZoomScrollView: UIScrollView {
    var isPaintZoomEnabled = false
    var shouldBeginPaintZoom: (() -> Bool)?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if self.isPaintZoomEnabled, gestureRecognizer === self.pinchGestureRecognizer || gestureRecognizer === self.panGestureRecognizer, let shouldBeginPaintZoom = self.shouldBeginPaintZoom, !shouldBeginPaintZoom() {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

public func chatMediaEditorZoomPanMinimumTouches(isPaintZoomEnabled: Bool) -> Int {
    return isPaintZoomEnabled ? 2 : 1
}

public func chatMediaEditorPhotoMaxZoomScale(viewportSize: CGSize, mediaSize: CGSize) -> CGFloat {
    guard mediaSize.width > 0.0, mediaSize.height > 0.0 else {
        return 1.0
    }
    let fill = max(viewportSize.width / mediaSize.width, viewportSize.height / mediaSize.height)
    return max(fill, 3.0)
}

public func chatMediaEditorZoomContentInsets(viewportSize: CGSize, mediaFrame: CGRect, zoomScale: CGFloat) -> UIEdgeInsets {
    func axis(viewport: CGFloat, mediaMin: CGFloat, mediaMax: CGFloat) -> (low: CGFloat, high: CGFloat) {
        let content = viewport * zoomScale
        let a = mediaMin * zoomScale
        let b = mediaMax * zoomScale
        if b - a >= viewport {
            return (-a, b - content)
        }
        let offset = (a + b) / 2.0 - (mediaMin + mediaMax) / 2.0
        return (-offset, offset + viewport - content)
    }
    let horizontal = axis(viewport: viewportSize.width, mediaMin: mediaFrame.minX, mediaMax: mediaFrame.maxX)
    let vertical = axis(viewport: viewportSize.height, mediaMin: mediaFrame.minY, mediaMax: mediaFrame.maxY)
    return UIEdgeInsets(top: vertical.low, left: horizontal.low, bottom: vertical.high, right: horizontal.high)
}

final class ChatMediaEditorSwipeDownGestureRecognizer: UIGestureRecognizer {
    private var startPoint: CGPoint?
    private var samples: [(point: CGPoint, timestamp: Double)] = []
    private(set) var translation: CGPoint = .zero

    var velocity: CGPoint {
        guard let last = self.samples.last else {
            return .zero
        }
        guard let first = self.samples.first(where: { last.timestamp - $0.timestamp <= 0.1 }), last.timestamp - first.timestamp > 0.001 else {
            return .zero
        }
        let dt = CGFloat(last.timestamp - first.timestamp)
        return CGPoint(x: (last.point.x - first.point.x) / dt, y: (last.point.y - first.point.y) / dt)
    }

    private func location(_ touch: UITouch) -> CGPoint {
        return touch.location(in: self.view?.window)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard self.startPoint == nil, touches.count == 1, let touch = touches.first else {
            if self.state == .possible {
                self.state = .failed
            } else if self.state == .began || self.state == .changed {
                self.state = .cancelled
            }
            return
        }
        let point = self.location(touch)
        self.startPoint = point
        self.samples = [(point, touch.timestamp)]
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let startPoint = self.startPoint, let touch = touches.first else {
            return
        }
        let point = self.location(touch)
        self.translation = CGPoint(x: point.x - startPoint.x, y: point.y - startPoint.y)
        self.samples.append((point, touch.timestamp))
        if self.samples.count > 8 {
            self.samples.removeFirst(self.samples.count - 8)
        }
        switch self.state {
        case .possible:
            switch chatMediaEditorSwipeDownDecision(translation: self.translation) {
            case .begin:
                self.state = .began
            case .fail:
                self.state = .failed
            case .undecided:
                break
            }
        case .began, .changed:
            self.state = .changed
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if self.state == .began || self.state == .changed {
            self.state = .ended
        } else {
            self.state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        if self.state == .began || self.state == .changed {
            self.state = .cancelled
        } else {
            self.state = .failed
        }
    }

    override func reset() {
        super.reset()
        self.startPoint = nil
        self.samples = []
        self.translation = .zero
    }
}

final class ChatMediaEditorPageView: UIView, UIScrollViewDelegate {
    var index: Int
    let zoomScrollView: UIScrollView
    let contentView: UIView
    let thumbnailView: UIImageView
    private let doubleTapRecognizer: UITapGestureRecognizer
    let singleTapRecognizer: UITapGestureRecognizer
    private(set) var mediaFrame: CGRect = .zero
    private var maxZoomScale: CGFloat = 1.0
    let thumbnailDisposable = MetaDisposable()
    var zoomUpdated: (() -> Void)?
    var tapped: (() -> Void)?

    var isTapEnabled = false {
        didSet {
            self.singleTapRecognizer.isEnabled = self.isTapEnabled
        }
    }

    var isZoomEnabled = false {
        didSet {
            if self.isZoomEnabled != oldValue {
                self.updateZoomInteraction()
                if !self.isZoomEnabled {
                    self.resetZoom(animated: false)
                }
            }
        }
    }

    var shouldBeginPaintZoom: (() -> Bool)? {
        get {
            return (self.zoomScrollView as? ChatMediaEditorZoomScrollView)?.shouldBeginPaintZoom
        }
        set {
            if let zoomScrollView = self.zoomScrollView as? ChatMediaEditorZoomScrollView {
                zoomScrollView.shouldBeginPaintZoom = newValue
            }
        }
    }

    var isPaintZoomEnabled = false {
        didSet {
            if self.isPaintZoomEnabled != oldValue {
                (self.zoomScrollView as? ChatMediaEditorZoomScrollView)?.isPaintZoomEnabled = self.isPaintZoomEnabled
                self.updateZoomInteraction()
                if !self.isPaintZoomEnabled {
                    self.resetZoom(animated: true)
                }
            }
        }
    }

    var zoomScale: CGFloat {
        return self.zoomScrollView.zoomScale
    }

    var isZoomed: Bool {
        return self.zoomScrollView.zoomScale > 1.001
    }

    init(index: Int) {
        self.index = index
        self.zoomScrollView = ChatMediaEditorZoomScrollView()
        self.zoomScrollView.showsHorizontalScrollIndicator = false
        self.zoomScrollView.showsVerticalScrollIndicator = false
        self.zoomScrollView.contentInsetAdjustmentBehavior = .never
        self.zoomScrollView.delaysContentTouches = false
        self.zoomScrollView.scrollsToTop = false
        self.zoomScrollView.decelerationRate = .fast
        self.zoomScrollView.minimumZoomScale = chatMediaEditorPhotoMinZoomScale
        self.zoomScrollView.maximumZoomScale = 1.0
        self.zoomScrollView.clipsToBounds = false
        self.contentView = UIView()
        self.thumbnailView = UIImageView()
        self.thumbnailView.contentMode = .scaleAspectFill
        self.thumbnailView.clipsToBounds = true
        self.doubleTapRecognizer = UITapGestureRecognizer()
        self.doubleTapRecognizer.numberOfTapsRequired = 2
        self.singleTapRecognizer = UITapGestureRecognizer()
        self.singleTapRecognizer.isEnabled = false

        super.init(frame: .zero)

        self.clipsToBounds = true
        self.addSubview(self.zoomScrollView)
        self.zoomScrollView.addSubview(self.contentView)
        self.contentView.addSubview(self.thumbnailView)
        self.zoomScrollView.delegate = self
        self.doubleTapRecognizer.addTarget(self, action: #selector(self.doubleTapped(_:)))
        self.zoomScrollView.addGestureRecognizer(self.doubleTapRecognizer)
        self.singleTapRecognizer.addTarget(self, action: #selector(self.singleTapped))
        self.singleTapRecognizer.require(toFail: self.doubleTapRecognizer)
        self.zoomScrollView.addGestureRecognizer(self.singleTapRecognizer)
        self.updateZoomInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.thumbnailDisposable.dispose()
    }

    private func updateZoomInteraction() {
        let isEnabled = self.isZoomEnabled || self.isPaintZoomEnabled
        self.zoomScrollView.pinchGestureRecognizer?.isEnabled = isEnabled
        self.zoomScrollView.isScrollEnabled = isEnabled
        self.zoomScrollView.panGestureRecognizer.minimumNumberOfTouches = chatMediaEditorZoomPanMinimumTouches(isPaintZoomEnabled: self.isPaintZoomEnabled)
        self.doubleTapRecognizer.isEnabled = self.isZoomEnabled
    }

    func update(mediaFrame: CGRect) {
        let size = self.bounds.size
        self.mediaFrame = mediaFrame
        self.maxZoomScale = chatMediaEditorPhotoMaxZoomScale(viewportSize: size, mediaSize: mediaFrame.size)
        if self.zoomScrollView.frame.size != size {
            self.resetZoom(animated: false)
            self.zoomScrollView.frame = CGRect(origin: .zero, size: size)
            self.contentView.frame = CGRect(origin: .zero, size: size)
            self.zoomScrollView.contentSize = size
        }
        self.zoomScrollView.maximumZoomScale = self.maxZoomScale
        self.thumbnailView.frame = mediaFrame
        self.updateInsets()
    }

    func resetZoom(animated: Bool, duration: Double = chatMediaEditorDoubleTapZoomDuration) {
        guard self.zoomScrollView.zoomScale != 1.0 else {
            return
        }
        if animated {
            UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
                self.zoomScrollView.zoomScale = 1.0
                self.updateInsets()
                self.zoomScrollView.contentOffset = .zero
            }, completion: { _ in
                self.zoomUpdated?()
            })
        } else {
            self.zoomScrollView.zoomScale = 1.0
            self.updateInsets()
            self.zoomScrollView.contentOffset = .zero
            self.zoomUpdated?()
        }
    }

    private func updateInsets() {
        let insets = chatMediaEditorZoomContentInsets(viewportSize: self.zoomScrollView.bounds.size, mediaFrame: self.mediaFrame, zoomScale: self.zoomScrollView.zoomScale)
        if self.zoomScrollView.contentInset != insets {
            self.zoomScrollView.contentInset = insets
        }
    }

    @objc private func singleTapped() {
        self.tapped?()
    }

    @objc private func doubleTapped(_ recognizer: UITapGestureRecognizer) {
        guard self.isZoomEnabled, recognizer.state == .ended else {
            return
        }
        if self.isZoomed {
            self.resetZoom(animated: true)
            return
        }
        let point = recognizer.location(in: self.contentView)
        guard self.mediaFrame.contains(point) else {
            return
        }
        let size = self.zoomScrollView.bounds.size
        let scale = self.maxZoomScale
        let mediaFrame = self.mediaFrame
        UIView.animate(withDuration: chatMediaEditorDoubleTapZoomDuration, delay: 0.0, options: [.curveEaseInOut], animations: {
            self.zoomScrollView.zoomScale = scale
            self.updateInsets()
            self.zoomScrollView.contentOffset = chatMediaEditorZoomTargetOffset(viewportSize: size, mediaFrame: mediaFrame, zoomScale: scale, focus: point)
        }, completion: { _ in
            self.zoomUpdated?()
        })
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.isZoomEnabled || self.isPaintZoomEnabled || abs(self.contentView.transform.a - 1.0) > 0.001 ? self.contentView : nil
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.updateInsets()
        self.zoomUpdated?()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale < 1.0 - 0.001 {
            self.resetZoom(animated: true, duration: chatMediaEditorZoomSpringBackDuration)
        } else if scale <= 1.001 {
            self.resetZoom(animated: false)
        }
        self.zoomUpdated?()
    }
}

final class ChatMediaEditorPagerView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let scrollView: UIScrollView
    let swipeDownRecognizer: ChatMediaEditorSwipeDownGestureRecognizer
    private(set) var pages: [Int: ChatMediaEditorPageView] = [:]
    private(set) var currentIndex: Int = 0
    private var count: Int = 0
    private var pageSize: CGSize = .zero

    var pageMediaFrame: ((Int) -> CGRect)?
    var configurePage: ((ChatMediaEditorPageView) -> Void)?
    var pageZoomUpdated: ((ChatMediaEditorPageView) -> Void)?
    var pageTapped: ((ChatMediaEditorPageView) -> Void)?
    var settled: ((Int) -> Void)?
    var canSwipeDown: (() -> Bool)?
    var swipeDownUpdated: ((ChatMediaEditorSwipeDownGestureRecognizer) -> Void)?
    var trackingUpdated: ((String, Bool) -> Void)?

    override init(frame: CGRect) {
        self.scrollView = UIScrollView()
        self.scrollView.isPagingEnabled = true
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.delaysContentTouches = false
        self.scrollView.scrollsToTop = false
        self.scrollView.clipsToBounds = false
        self.swipeDownRecognizer = ChatMediaEditorSwipeDownGestureRecognizer()

        super.init(frame: frame)

        self.addSubview(self.scrollView)
        self.scrollView.delegate = self
        self.swipeDownRecognizer.delegate = self
        self.swipeDownRecognizer.addTarget(self, action: #selector(self.swipeDownGesture(_:)))
        self.addGestureRecognizer(self.swipeDownRecognizer)
        self.scrollView.panGestureRecognizer.require(toFail: self.swipeDownRecognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isScrolling: Bool {
        return self.scrollView.isTracking || self.scrollView.isDragging || self.scrollView.isDecelerating
    }

    func page(at index: Int) -> ChatMediaEditorPageView? {
        return self.pages[index]
    }

    func setScrollEnabled(_ enabled: Bool) {
        if self.scrollView.isScrollEnabled != enabled {
            self.scrollView.isScrollEnabled = enabled
        }
    }

    func update(size: CGSize, count: Int, currentIndex: Int) {
        let pageWidth = size.width + chatMediaEditorPagerPageSpacing
        let layoutChanged = self.pageSize != size || self.count != count || self.currentIndex != currentIndex
        self.pageSize = size
        self.count = count
        self.currentIndex = currentIndex
        let scrollSize = CGSize(width: pageWidth, height: size.height)
        if self.scrollView.bounds.size != scrollSize {
            self.scrollView.bounds = CGRect(origin: self.scrollView.bounds.origin, size: scrollSize)
        }
        self.scrollView.center = CGPoint(x: scrollSize.width / 2.0, y: scrollSize.height / 2.0)
        let contentSize = CGSize(width: pageWidth * CGFloat(max(1, count)), height: size.height)
        if self.scrollView.contentSize != contentSize {
            self.scrollView.contentSize = contentSize
        }
        if layoutChanged && !self.isScrolling {
            self.scrollView.contentOffset = CGPoint(x: chatMediaEditorPagerOffset(index: currentIndex, width: size.width), y: 0.0)
        }
        self.updatePages(relayout: true)
    }

    func scrollToPage(_ index: Int, animated: Bool) {
        guard index >= 0, index < self.count, self.pageSize.width > 0.0 else {
            return
        }
        self.scrollView.setContentOffset(CGPoint(x: chatMediaEditorPagerOffset(index: index, width: self.pageSize.width), y: 0.0), animated: animated)
        if !animated {
            self.settle()
        }
        self.releaseTrackingIfIdle()
    }

    func reloadPage(at index: Int) {
        if let page = self.pages[index] {
            self.configurePage?(page)
        }
    }

    func setSwipeOffset(_ offset: CGFloat) {
        self.scrollView.transform = CGAffineTransform(translationX: 0.0, y: offset)
    }

    private func updatePages(relayout: Bool) {
        let layout = chatMediaEditorPagerLayout(width: self.pageSize.width, height: self.pageSize.height, index: self.currentIndex, offset: self.scrollView.contentOffset.x, count: self.count)
        var visible = Set<Int>()
        for (index, frame) in layout {
            visible.insert(index)
            let page: ChatMediaEditorPageView
            var isNew = false
            if let current = self.pages[index] {
                page = current
            } else {
                page = ChatMediaEditorPageView(index: index)
                page.zoomUpdated = { [weak self, weak page] in
                    guard let self, let page else {
                        return
                    }
                    self.pageZoomUpdated?(page)
                }
                page.tapped = { [weak self, weak page] in
                    guard let self, let page else {
                        return
                    }
                    self.pageTapped?(page)
                }
                self.pages[index] = page
                self.scrollView.addSubview(page)
                isNew = true
            }
            if isNew || relayout || page.frame != frame {
                page.frame = frame
                page.update(mediaFrame: self.pageMediaFrame?(index) ?? .zero)
            }
            if isNew {
                self.configurePage?(page)
            }
            let parallaxOffset = chatMediaEditorPagerParallaxOffset(pageFrame: frame, contentOffset: self.scrollView.contentOffset.x)
            page.layer.sublayerTransform = CATransform3DMakeTranslation(parallaxOffset, 0.0, 0.0)
        }
        for (index, page) in self.pages where !visible.contains(index) {
            page.thumbnailDisposable.set(nil)
            page.removeFromSuperview()
            self.pages[index] = nil
        }
    }

    private func settle() {
        let index = chatMediaEditorPagerSettledIndex(offset: self.scrollView.contentOffset.x, width: self.pageSize.width, count: self.count)
        guard index != self.currentIndex else {
            return
        }
        self.currentIndex = index
        for (pageIndex, page) in self.pages where pageIndex != index {
            page.resetZoom(animated: false)
        }
        self.updatePages(relayout: false)
        self.settled?(index)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updatePages(relayout: false)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.trackingUpdated?("pager", true)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.settle()
            self.trackingUpdated?("pager", false)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.settle()
        self.trackingUpdated?("pager", false)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.settle()
        self.releaseTrackingIfIdle()
    }

    private func releaseTrackingIfIdle() {
        if !self.scrollView.isTracking {
            self.trackingUpdated?("pager", false)
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.swipeDownRecognizer {
            return !self.scrollView.isDragging && !self.scrollView.isDecelerating && (self.canSwipeDown?() ?? false)
        }
        return true
    }

    @objc private func swipeDownGesture(_ recognizer: ChatMediaEditorSwipeDownGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.trackingUpdated?("swipeDown", true)
        case .ended, .cancelled, .failed:
            self.trackingUpdated?("swipeDown", false)
        default:
            break
        }
        self.swipeDownUpdated?(recognizer)
    }
}
