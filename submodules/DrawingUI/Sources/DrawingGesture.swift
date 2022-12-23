import Foundation
import UIKit

public typealias TouchEventIdentifier = String
public typealias PointIdentifier = String
public typealias EstimationUpdateIndex = NSNumber

class Touch: Equatable, Hashable {
    public let touchIdentifier: UITouchIdentifier
    lazy public var pointIdentifier: PointIdentifier = {
        if let estimationUpdateIndex = estimationUpdateIndex {
            return touchIdentifier + ":\(estimationUpdateIndex)"
        } else {
            return touchIdentifier + ":" + identifier
        }
    }()
    public let identifier: String
    public let timestamp: TimeInterval
    public let type: UITouch.TouchType
    public let phase: UITouch.Phase
    public let force: CGFloat
    public let maximumPossibleForce: CGFloat
    public let altitudeAngle: CGFloat
    public let azimuthUnitVector: CGVector
    public let azimuth: CGFloat
    public let location: CGPoint
    public let estimationUpdateIndex: EstimationUpdateIndex?
    public let estimatedProperties: UITouch.Properties
    public let estimatedPropertiesExpectingUpdates: UITouch.Properties
    public let isUpdate: Bool
    public let isPrediction: Bool

    public let view: UIView?

    public var expectsLocationUpdate: Bool {
        return estimatedPropertiesExpectingUpdates.contains(UITouch.Properties.location)
    }

    public var expectsForceUpdate: Bool {
        return estimatedPropertiesExpectingUpdates.contains(UITouch.Properties.force)
    }

    public var expectsAzimuthUpdate: Bool {
        return estimatedPropertiesExpectingUpdates.contains(UITouch.Properties.azimuth)
    }

    public var expectsUpdate: Bool {
        return expectsForceUpdate || expectsAzimuthUpdate || expectsLocationUpdate
    }

    public convenience init(
        coalescedTouch: UITouch,
        touch: UITouch,
        in view: UIView,
        isUpdate: Bool,
        isPrediction: Bool,
        phase: UITouch.Phase? = nil,
        transform: CGAffineTransform = .identity
    ) {
        let originalLocation = coalescedTouch.location(in: view)
        let location = !transform.isIdentity ? originalLocation.applying(transform) : originalLocation

        self.init(
            identifier: UUID.init().uuidString,
            touchIdentifier: touch.identifer,
            timestamp: coalescedTouch.timestamp,
            type: coalescedTouch.type,
            phase: phase ?? coalescedTouch.phase,
            force: coalescedTouch.force,
            maximumPossibleForce: coalescedTouch.maximumPossibleForce,
            altitudeAngle: coalescedTouch.altitudeAngle,
            azimuthUnitVector: coalescedTouch.azimuthUnitVector(in: view),
            azimuth: coalescedTouch.azimuthAngle(in: view),
            location: location,
            estimationUpdateIndex: coalescedTouch.estimationUpdateIndex,
            estimatedProperties: coalescedTouch.estimatedProperties,
            estimatedPropertiesExpectingUpdates: coalescedTouch.estimatedPropertiesExpectingUpdates,
            isUpdate: isUpdate,
            isPrediction: isPrediction,
            in: view
        )
    }

    public init(
        identifier: TouchEventIdentifier,
        touchIdentifier: UITouchIdentifier,
        timestamp: TimeInterval,
        type: UITouch.TouchType,
        phase: UITouch.Phase,
        force: CGFloat,
        maximumPossibleForce: CGFloat,
        altitudeAngle: CGFloat,
        azimuthUnitVector: CGVector,
        azimuth: CGFloat,
        location: CGPoint,
        estimationUpdateIndex: EstimationUpdateIndex?,
        estimatedProperties: UITouch.Properties,
        estimatedPropertiesExpectingUpdates: UITouch.Properties,
        isUpdate: Bool,
        isPrediction: Bool,
        in view: UIView?
    ) {
        self.identifier = identifier
        self.touchIdentifier = touchIdentifier
        self.timestamp = timestamp
        self.type = type
        self.phase = phase
        self.force = force
        self.maximumPossibleForce = maximumPossibleForce
        self.altitudeAngle = altitudeAngle
        self.azimuthUnitVector = azimuthUnitVector
        self.azimuth = azimuth
        self.location = location
        self.estimationUpdateIndex = estimationUpdateIndex
        self.estimatedProperties = estimatedProperties
        self.estimatedPropertiesExpectingUpdates = estimatedPropertiesExpectingUpdates
        self.isUpdate = isUpdate
        self.isPrediction = isPrediction
        self.view = view
    }
    
    public static func == (lhs: Touch, rhs: Touch) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

class DrawingGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var shouldBegin: (CGPoint) -> Bool = { _ in return true }
    var onTouches: ([Touch]) -> Void = { _ in }
    
    var transform: CGAffineTransform = .identity
    
    var usePredictedTouches = false
    
    private var currentTouches = Set<UITouch>()
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
        self.cancelsTouchesInView = false
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
        self.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.stylus.rawValue)
        ]
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: self.view)
        if self.shouldBegin(location) {
            return true
        } else {
            return false
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        return true
    }
    
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        self.process(touches: touches, with: nil, isUpdate: true)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let location = touches.first?.location(in: self.view), touches.count == 1 && self.shouldBegin(location) {
            super.touchesBegan(touches, with: event)
            
            self.process(touches: touches, with: event)
            self.state = .began
        } else {
            self.state = .cancelled
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if touches.count > 1 {
            self.state = .cancelled
        } else {
            super.touchesMoved(touches, with: event)
            self.process(touches: touches, with: event)
            
            self.state = .changed
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.process(touches: touches, with: event)
        
        self.state = .ended
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.state = .cancelled
    }
    
    func process(touches: Set<UITouch>, with event: UIEvent?, isUpdate: Bool = false) {
        guard let view = self.view else {
            return
        }
        
        var allTouches: [Touch] = []

        if let touch = touches.first {
            allTouches.append(Touch(
                coalescedTouch: touch,
                touch: touch,
                in: view,
                isUpdate: isUpdate,
                isPrediction: false,
                transform: self.transform
            ))
        }
        
        self.onTouches(allTouches)
    }
}

class DrawingGesturePipeline {
    struct Point {
        let location: CGPoint
        let velocity: CGFloat
        let timestamp: Double
        
        var x: CGFloat {
            return self.location.x
        }
        
        var y: CGFloat {
            return self.location.y
        }
    }
    
    enum Mode {
        case direct
        case location
        case smoothCurve
        case polyline
    }
    
    enum DrawingGestureState {
        case began
        case changed
        case ended
        case cancelled
    }
    
    enum DrawingResult {
        case point(DrawingGesturePipeline.Point)
        case location(Polyline.Point)
        case smoothCurve(BezierPath)
        case polyline(Polyline)
    }
    
    private var pendingTouches: [Touch] = []
    var onDrawing: (DrawingGestureState, DrawingResult) -> Void = { _, _ in }
    
    var gestureRecognizer: DrawingGestureRecognizer?
    var transform: CGAffineTransform = .identity {
        didSet {
            self.gestureRecognizer?.transform = transform
        }
    }
    
    var mode: Mode = .location
    
    init(view: DrawingView) {
        let gestureRecognizer = DrawingGestureRecognizer(target: self, action: #selector(self.handleGesture(_:)))
        gestureRecognizer.onTouches = { [weak self] touches in
            self?.pendingTouches.append(contentsOf: touches)
        }
        self.gestureRecognizer = gestureRecognizer
        view.addGestureRecognizer(gestureRecognizer)
    }
    
    var previousPoint: Point?
    @objc private func handleGesture(_ gestureRecognizer: DrawingGestureRecognizer) {
        let state: DrawingGestureState
        switch gestureRecognizer.state {
        case .began:
            state = .began
        case .changed:
            state = .changed
        case .ended:
            state = .ended
        case .cancelled:
            state = .cancelled
        case .failed:
            state = .cancelled
        case .possible:
            state = .cancelled
        @unknown default:
            state = .cancelled
        }
        
        if case .direct = self.mode, let touch = self.pendingTouches.first {
            if state == .began {
                self.previousPoint = nil
            }
            
            var velocity: Double = 0.0
            if let previousPoint = self.previousPoint {
                let distance = touch.location.distance(to: previousPoint.location)
                let elapsed = max(0.0, touch.timestamp - previousPoint.timestamp)
                velocity = elapsed > 0.0 ? distance / elapsed : 0.0
            } else {
                velocity = 0.0
            }
            
            let point = Point(location: touch.location, velocity: velocity, timestamp: touch.timestamp)
            self.previousPoint = point
            
            self.onDrawing(state, .point(point))
            
            self.pendingTouches.removeAll()
            return
        }
        
        let touchDeltas = self.processTouchEvents(self.pendingTouches)
        let polylineDeltas = self.processTouchPaths(inputDeltas: touchDeltas)
        let simplifiedPolylineDeltas = self.simplifyPolylines(inputDeltas: polylineDeltas)

        switch self.mode {
        case .location:
            if let touchPath = self.touchPaths.last, let point = touchPath.points.last {
                self.onDrawing(state, .location(Polyline.Point(touchPoint: point)))
            }
        case .smoothCurve:
            if let path = self.processPolylines(inputDeltas: simplifiedPolylineDeltas) {
                self.onDrawing(state, .smoothCurve(path))
            }
        case .polyline:
            if let polyline = self.simplifiedPolylines.last {
                self.onDrawing(state, .polyline(polyline))
            }
        case .direct:
            break
        }
        
        self.pendingTouches.removeAll()
    }
    
    enum TouchPathDelta: Equatable {
        case addedTouchPath(index: Int)
        case updatedTouchPath(index: Int, updatedIndexes: MinMaxIndex)
        case completedTouchPath(index: Int)
    }
    
    private var touchPaths: [TouchPath] = []
    private var touchToIndex: [UITouchIdentifier: Int] = [:]
    private func processTouchEvents(_ touches: [Touch]) -> [TouchPathDelta] {
        var deltas: [TouchPathDelta] = []
        var processedTouchIdentifiers: [UITouchIdentifier] = []
        let updatedEventsPerTouch = touches.reduce(into: [String: [Touch]](), { (result, event) in
            if result[event.touchIdentifier] != nil {
                result[event.touchIdentifier]?.append(event)
            } else {
                result[event.touchIdentifier] = [event]
            }
        })

        for touchToProcess in touches {
            let touchIdentifier = touchToProcess.touchIdentifier
            guard !processedTouchIdentifiers.contains(touchIdentifier), let events = updatedEventsPerTouch[touchIdentifier] else {
                continue
            }
            
            processedTouchIdentifiers.append(touchIdentifier)
            if let index = self.touchToIndex[touchIdentifier] {
                let path = self.touchPaths[index]
                let updatedIndexes = path.add(touchEvents: events)
                deltas.append(.updatedTouchPath(index: index, updatedIndexes: updatedIndexes))
                
                if path.isComplete {
                    deltas.append(.completedTouchPath(index: index))
                }
            } else if let touchIdentifier = events.first?.touchIdentifier, let path = TouchPath(touchEvents: events) {
                let index = self.touchPaths.count
                self.touchToIndex[touchIdentifier] = index
                self.touchPaths.append(path)
                deltas.append(.addedTouchPath(index: index))
                
                if path.isComplete {
                    deltas.append(.completedTouchPath(index: index))
                }
            }
        }
        return deltas
    }
    
    enum PolylineDelta: Equatable {
        case addedPolyline(index: Int)
        case updatedPolyline(index: Int, updatedIndexes: MinMaxIndex)
        case completedPolyline(index: Int)
    }
    
    private var indexToIndex: [Int: Int] = [:]
    private var polylines: [Polyline] = []
    func processTouchPaths(inputDeltas: [TouchPathDelta]) -> [PolylineDelta] {
        var deltas: [PolylineDelta] = []
        for delta in inputDeltas {
            switch delta {
            case .addedTouchPath(let pathIndex):
                let line = self.touchPaths[pathIndex]
                let smoothStroke = Polyline(touchPath: line)
                let index = polylines.count
                indexToIndex[pathIndex] = index
                polylines.append(smoothStroke)
                deltas.append(.addedPolyline(index: index))
            case .updatedTouchPath(let pathIndex, let indexSet):
                let line = self.touchPaths[pathIndex]
                if let index = indexToIndex[pathIndex] {
                    let updates = polylines[index].update(with: line, indexSet: indexSet)
                    deltas.append(.updatedPolyline(index: index, updatedIndexes: updates))
                }
            case .completedTouchPath(let pointCollectionIndex):
                if let index = indexToIndex[pointCollectionIndex] {
                    deltas.append(.completedPolyline(index: index))
                }
            }
        }
        
        return deltas
    }
    
    var simplifiedPolylines: [Polyline] = []
    func simplifyPolylines(inputDeltas: [PolylineDelta]) -> [PolylineDelta] {
        var outDeltas: [PolylineDelta] = []
        
        for delta in inputDeltas {
            switch delta {
            case .addedPolyline(let strokeIndex):
                assert(strokeIndex == self.simplifiedPolylines.count)
                let line = self.polylines[strokeIndex]
                self.simplifiedPolylines.append(line)
                let indexes = MinMaxIndex(0..<line.points.count)
                let _ = smoothStroke(stroke: &self.simplifiedPolylines[strokeIndex], at: indexes, input: line)
                outDeltas.append(delta)
            case .completedPolyline(let strokeIndex):
                self.simplifiedPolylines[strokeIndex].isComplete = true
                outDeltas.append(delta)
            case .updatedPolyline(let strokeIndex, let indexes):
                let line = self.polylines[strokeIndex]
                let updatedIndexes = smoothStroke(stroke: &self.simplifiedPolylines[strokeIndex], at: indexes, input: line)
                outDeltas.append(.updatedPolyline(index: strokeIndex, updatedIndexes: updatedIndexes))
            }
        }
        
        return outDeltas
    }
    
    class Coeffs {
        private let index: Int
        private let windowSize: Int
        private var cache: [CGFloat]?

        init(index: Int, windowSize: Int) {
            self.index = index
            self.windowSize = windowSize
        }

        func weight(_ windowLoc: Int, _ order: Int, _ derivative: Int) -> CGFloat {
            guard abs(windowLoc) <= windowSize else { fatalError("Invalid coefficient") }
            if let cached = cache {
                return cached[abs(windowLoc)]
            }
            var coeffs: [CGFloat] = []
            for windowLoc in 0...windowSize {
                coeffs.append(Self.calcWeight(index, windowLoc, windowSize, order, derivative))
            }

            cache = coeffs

            return coeffs[abs(windowLoc)]
        }

        // MARK: - Coefficients

        /// calculates the generalised factorial (a)(a-1)...(a-b+1)
        private static func genFact(_ a: Int, _ b: Int) -> CGFloat {
            var gf: CGFloat = 1.0

            for jj in (a - b + 1) ..< (a + 1) {
                gf *= CGFloat(jj)
            }
            return gf
        }

        private static func gramPoly(_ index: Int, _ window: Int, _ order: Int, _ derivative: Int) -> CGFloat {
            var gp_val: CGFloat

            if order > 0 {
                let g1 = gramPoly(index, window, order - 1, derivative)
                let g2 = gramPoly(index, window, order - 1, derivative - 1)
                let g3 = gramPoly(index, window, order - 2, derivative)
                let i: CGFloat = CGFloat(index)
                let m: CGFloat = CGFloat(window)
                let k: CGFloat = CGFloat(order)
                let s: CGFloat = CGFloat(derivative)
                gp_val = (4.0 * k - 2.0) / (k * (2.0 * m - k + 1.0)) * (i * g1 + s * g2)
                    - ((k - 1.0) * (2.0 * m + k)) / (k * (2.0 * m - k + 1.0)) * g3
            } else if order == 0 && derivative == 0 {
                gp_val = 1.0
            } else {
                gp_val = 0.0
            }
            return gp_val
        }

        private static func calcWeight(_ index: Int, _ windowLoc: Int, _ windowSize: Int, _ order: Int, _ derivative: Int) -> CGFloat {
            var sum: CGFloat = 0.0

            for k in 0 ..< order + 1 {
                sum += CGFloat(2 * k + 1) * CGFloat(genFact(2 * windowSize, k) / genFact(2 * windowSize + k + 1, k + 1))
                    * gramPoly(index, windowSize, k, 0) * gramPoly(windowLoc, windowSize, k, derivative)
            }

            return sum
        }
    }

    
    private var window: Int = 2
    private var strength: CGFloat = 1
    
    var deriv: Int = 0
    var order: Int = 3
    var coeffs: [Coeffs] = []
    
    private func smoothStroke(stroke: inout Polyline, at indexes: MinMaxIndex?, input: Polyline) -> MinMaxIndex {
        if input.points.count > stroke.points.count {
            stroke.points.append(contentsOf: input.points[stroke.points.count...])
        } else if input.points.count < stroke.points.count {
            stroke.points.removeSubrange(input.points.count...)
        }
        let outIndexes = { () -> MinMaxIndex in
            if let indexes = indexes,
               let minIndex = indexes.first,
               let maxIndex = indexes.last {
                var outIndexes = MinMaxIndex()
                let start = max(0, minIndex - window)
                let end = min(stroke.points.count - 1, maxIndex + window)
                outIndexes.insert(integersIn: start...end)
                return outIndexes
            }
            return MinMaxIndex(stroke.points.indices)
        }()

        for pIndex in outIndexes {
            let minWin = min(min(window, pIndex), stroke.points.count - 1 - pIndex)
            // copy over the point in question so that not only our location will be smoothed below,
            // but also the azimuth/altitude/etc will be the same
            stroke.points[pIndex] = input.points[pIndex]
            while coeffs.count < minWin + 1 {
                coeffs.append(Coeffs(index: 0, windowSize: coeffs.count))
            }
            if minWin > 1 {
                var outPoint = CGPoint.zero
                for windowPos in -minWin ... minWin {
                    let wght = coeffs[minWin].weight(windowPos, order, deriv)
                    outPoint.x += wght * input.points[pIndex + windowPos].location.x
                    outPoint.y += wght * input.points[pIndex + windowPos].location.y
                }
                let origPoint = stroke.points[pIndex].location

                stroke.points[pIndex].location = origPoint * CGFloat(1 - strength) + outPoint * strength
            }
        }

        return outIndexes
    }
        
    private var builders: [BezierBuilder] = []
    private var bezierIndexToIndex: [Int: Int] = [:]
    func processPolylines(inputDeltas: [PolylineDelta]) -> BezierPath? {
        for delta in inputDeltas {
            switch delta {
            case .addedPolyline(let lineIndex):
                assert(bezierIndexToIndex[lineIndex] == nil, "Cannot add existing line")
                let line = self.simplifiedPolylines[lineIndex]
                let builder = BezierBuilder(smoother: Smoother())
                builder.update(with: line, at: MinMaxIndex(0 ..< line.points.count))
                let builderIndex = builders.count
                bezierIndexToIndex[lineIndex] = builderIndex
                builders.append(builder)
            case .updatedPolyline(let lineIndex, let updatedIndexes):
                let line = self.simplifiedPolylines[lineIndex]
                guard let builderIndex = bezierIndexToIndex[lineIndex] else {
                    continue
                }
                let builder = builders[builderIndex]
                let _ = builder.update(with: line, at: updatedIndexes)
            case .completedPolyline:
                break
            }
        }

        return builders.last?.path
    }
    
}

private var TOUCH_IDENTIFIER: UInt8 = 0
public typealias UITouchIdentifier = String

extension UITouch {
    var identifer: UITouchIdentifier {
        if let identifier = objc_getAssociatedObject(self, &TOUCH_IDENTIFIER) as? String {
            return identifier
        } else {
            let identifier = UUID().uuidString
            objc_setAssociatedObject(self, &TOUCH_IDENTIFIER, identifier, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return identifier
        }
    }
}

public struct MinMaxIndex: Sequence, Equatable {
    private var start: Int
    private var end: Int

    public static let null = MinMaxIndex()

    public init() {
        start = .max
        end = .max
    }

    public init(_ indexes: ClosedRange<Int>) {
        guard let first = indexes.first, let last = indexes.last else { self = .null; return }
        start = first
        end = last
    }

    public init(_ indexes: Range<Int>) {
        guard let first = indexes.first, let last = indexes.last else { self = .null; return }
        start = first
        end = last
    }

    public init(_ integers: [Int]) {
        guard !integers.isEmpty else { self = .null; return }
        start = integers.min()!
        end = integers.max()!
    }

    public init(_ integer: Int) {
        start = integer
        end = integer
    }

    public init(_ indexSet: IndexSet) {
        guard !indexSet.isEmpty else { self = .null; return }
        start = indexSet.min()!
        end = indexSet.max()!
    }

    public var count: Int {
        guard self != .null else { return 0 }
        return end - start + 1
    }

    public var first: Int? {
        guard self != .null else { return nil }
        return start
    }

    public var last: Int? {
        guard self != .null else { return nil }
        return end
    }

    @inlinable @inline(__always)
    public func asIndexSet() -> IndexSet {
        guard let first = first, let last = last else { return IndexSet() }
        return IndexSet(integersIn: first...last)
    }

    public mutating func insert(_ index: Int) {
        if self == Self.null {
            start = index
            end = index
        } else {
            start = Swift.min(start, index)
            end = Swift.max(end, index)
        }
    }

    @inlinable @inline(__always)
    public mutating func insert(integersIn indexes: ClosedRange<Int>) {
        guard let first = indexes.first, let last = indexes.last else { return }
        insert(first)
        insert(last)
    }

    public mutating func remove(_ index: Int) {
        if start == index {
            start += 1
        }
        if end == index {
            end -= 1
        }
        if start > end {
            start = .max
            end = .max
        }
    }

    @inlinable @inline(__always)
    public func contains(_ index: Int) -> Bool {
        guard let first = first, let last = last else { return false }
        return index >= first && index <= last
    }
    
    public func makeIterator() -> Iterator {
        return Iterator(min: start, max: end)
    }

    public struct Iterator: IteratorProtocol {
        public typealias Element = Int

        var min: Int
        let max: Int

        init(min: Int, max: Int) {
            self.min = min
            self.max = max
        }

        public mutating func next() -> Int? {
            if min == max, min == .max {
                return nil
            } else if min > max {
                return nil
            } else {
                let ret = min
                min += 1
                return ret
            }
        }
    }
}

extension Array {
    @inline(__always) @inlinable
    mutating func pop() -> Element? {
        guard !isEmpty else { return nil }
        return removeLast()
    }
    
    @inline(__always) @inlinable
    mutating func dequeue() -> Element? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }
}


class TouchPath: Hashable {
    class Point: Hashable {
        public private(set) var events: [Touch]

        public var event: Touch {
            return events.last!
        }

        public var expectsUpdate: Bool {
            return self.event.isPrediction || self.event.expectsUpdate
        }

        public var isPrediction: Bool {
            return events.allSatisfy({ $0.isPrediction })
        }

        public init(event: Touch) {
            events = [event]
            events.reserveCapacity(10)
        }

        func add(event: Touch) {
            events.append(event)
        }
        
        static func == (lhs: Point, rhs: Point) -> Bool {
            return lhs.expectsUpdate == rhs.expectsUpdate && lhs.events == rhs.events
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(events)
        }
    }
    
    public private(set) var touchIdentifier: String

    private var _points: [Point]?
    public var points: [Point] {
        if let _points = _points {
            return _points
        }
        let ret = confirmedPoints + predictedPoints
        _points = ret
        return ret
    }
    public var bounds: CGRect {
        return points.reduce(.null) { partialResult, point -> CGRect in
            return CGRect(x: min(partialResult.origin.x, point.event.location.x),
                          y: min(partialResult.origin.y, point.event.location.y),
                          width: max(partialResult.origin.x, point.event.location.x),
                          height: max(partialResult.origin.y, point.event.location.y))
        }
    }
    public var isComplete: Bool {
        let phase = confirmedPoints.last?.event.phase
        return (phase == .ended || phase == .cancelled) && predictedPoints.isEmpty
    }

    private var confirmedPoints: [Point] {
        didSet {
            _points = nil
        }
    }
    
    private var predictedPoints: [Point] {
        didSet {
            _points = nil
        }
    }

    private var consumable: [Point]
    private var expectingUpdate: Set<String>
    private var eventToPoint: [PointIdentifier: Point]
    private var eventToIndex: [PointIdentifier: Int]

    init?(touchEvents: [Touch]) {
        guard !touchEvents.isEmpty else { return nil }
        self.confirmedPoints = []
        self.predictedPoints = []
        self.consumable = []
        self.eventToPoint = [:]
        self.eventToIndex = [:]
        self.expectingUpdate = Set()
        self.touchIdentifier = touchEvents.first!.touchIdentifier
        add(touchEvents: touchEvents)
    }

    @discardableResult
    func add(touchEvents: [Touch]) -> MinMaxIndex {
        var indexSet = MinMaxIndex()
        let startingCount = points.count

        for event in touchEvents {
            assert(touchIdentifier == event.touchIdentifier)
            if event.isPrediction {
                if let prediction = consumable.dequeue() {
                    prediction.add(event: event)
                    predictedPoints.append(prediction)
                    let index = confirmedPoints.count + predictedPoints.count - 1
                    indexSet.insert(index)
                } else {
                    let prediction = Point(event: event)
                    predictedPoints.append(prediction)
                    let index = confirmedPoints.count + predictedPoints.count - 1
                    indexSet.insert(index)
                }
            } else if eventToPoint[event.pointIdentifier] != nil, let index = eventToIndex[event.pointIdentifier] {
                eventToPoint[event.pointIdentifier]?.add(event: event)
                if !event.expectsUpdate {
                    self.expectingUpdate.remove(event.pointIdentifier)
                }
                indexSet.insert(index)

                if event.phase == .ended || event.phase == .cancelled {
                    consumable.append(contentsOf: predictedPoints)
                    predictedPoints.removeAll()
                }
            } else if isComplete {
            } else {
                consumable.append(contentsOf: predictedPoints)
                predictedPoints.removeAll()

                if let point = consumable.dequeue() ?? predictedPoints.dequeue() {
                    if event.expectsUpdate {
                        self.expectingUpdate.insert(event.pointIdentifier)
                    }
                    point.add(event: event)
                    eventToPoint[event.pointIdentifier] = point
                    confirmedPoints.append(point)
                    let index = confirmedPoints.count - 1
                    eventToIndex[event.pointIdentifier] = index
                    indexSet.insert(index)
                } else {
                    if event.expectsUpdate {
                        self.expectingUpdate.insert(event.pointIdentifier)
                    }
                    let point = Point(event: event)
                    eventToPoint[event.pointIdentifier] = point
                    confirmedPoints.append(point)
                    let index = confirmedPoints.count - 1
                    eventToIndex[event.pointIdentifier] = index
                    indexSet.insert(index)
                }
            }
        }

        for index in consumable.indices {
            let possiblyRemovedIndex = confirmedPoints.count + predictedPoints.count + index
            if possiblyRemovedIndex < startingCount {
                indexSet.insert(possiblyRemovedIndex)
            } else {
                indexSet.remove(possiblyRemovedIndex)
            }
        }

        return indexSet
    }
    
    public static func == (lhs: TouchPath, rhs: TouchPath) -> Bool {
        return lhs.touchIdentifier == rhs.touchIdentifier && lhs.points == rhs.points
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(touchIdentifier)
    }
}

struct Polyline {
    struct Point: Equatable {
        var location: CGPoint
        var force: CGFloat
        var altitudeAngle: CGFloat
        var azimuth: CGFloat
        var velocity: CGFloat = 0.0

        let touchPoint: TouchPath.Point
        var event: Touch {
            return touchPoint.event
        }
        var expectsUpdate: Bool {
            return touchPoint.expectsUpdate
        }
        
        var x: CGFloat {
            return self.location.x
        }
        
        var y: CGFloat {
            return self.location.y
        }
        
        init(
            location: CGPoint,
            force: CGFloat,
            altitudeAngle: CGFloat,
            azimuth: CGFloat,
            velocity: CGFloat,
            touchPoint: TouchPath.Point
        ) {
            self.location = location
            self.force = force
            self.altitudeAngle = altitudeAngle
            self.azimuth = azimuth
            self.touchPoint = touchPoint
        }
    
        init(touchPoint: TouchPath.Point) {
            self.location = touchPoint.event.location
            self.force = touchPoint.event.force
            self.altitudeAngle = touchPoint.event.altitudeAngle
            self.azimuth = touchPoint.event.azimuth

            self.touchPoint = touchPoint
        }
        
        func offsetBy(_ point: CGPoint) -> Polyline.Point {
            return Point(
                location: self.location.offsetBy(dx: point.x, dy: point.y),
                force: self.force,
                altitudeAngle: self.altitudeAngle,
                azimuth: self.azimuth,
                velocity: self.velocity,
                touchPoint: self.touchPoint
            )
        }
        
        func withLocation(_ point: CGPoint) -> Polyline.Point {
            return Point(
                location: point,
                force: self.force,
                altitudeAngle: self.altitudeAngle,
                azimuth: self.azimuth,
                velocity: self.velocity,
                touchPoint: self.touchPoint
            )
        }
    }
    
    var isComplete: Bool
    let touchIdentifier: String
    var points: [Point]
    var bounds: CGRect {
        return self.points.reduce(.null) { partialResult, point -> CGRect in
            return CGRect(x: min(partialResult.origin.x, point.x),
                          y: min(partialResult.origin.y, point.y),
                          width: max(partialResult.size.width, point.x),
                          height: max(partialResult.size.height, point.y))
        }
    }
    init(touchPath: TouchPath) {
        isComplete = touchPath.isComplete
        touchIdentifier = touchPath.touchIdentifier
        
        var points: [Point] = []
        var previousTouchPoint: TouchPath.Point?
        for touchPoint in touchPath.points {
            var point = Point(touchPoint: touchPoint)
            if let previousTouchPoint = previousTouchPoint {
                let distance = touchPoint.event.location.distance(to: previousTouchPoint.event.location)
                let elapsed = max(0.0, touchPoint.event.timestamp - previousTouchPoint.event.timestamp)
                let velocity = elapsed > 0.0 ? distance / elapsed : 0.0
                point.velocity = velocity
            }
            points.append(point)
            previousTouchPoint = touchPoint
        }
        self.points = points
    }

    init(points: [Point]) {
        self.isComplete = true
        self.touchIdentifier = points.first?.event.touchIdentifier ?? ""
        self.points = points
    }

    mutating func update(with path: TouchPath, indexSet: MinMaxIndex) -> MinMaxIndex {
        var indexesToRemove = MinMaxIndex()
        for index in indexSet {
            if index < path.points.count {
                if index < points.count {
                    points[index].location = path.points[index].event.location
                    points[index].force = path.points[index].event.force
                    points[index].azimuth = path.points[index].event.azimuth
                    points[index].altitudeAngle = path.points[index].event.altitudeAngle
                    
                    if index > 0 {
                        let previousTouchPoint = points[index - 1]
                        let distance = path.points[index].event.location.distance(to: previousTouchPoint.event.location)
                        let elapsed = max(0.0, path.points[index].event.timestamp - previousTouchPoint.event.timestamp)
                        let velocity = elapsed > 0.0 ? distance / elapsed : 0.0
                        points[index].velocity = velocity
                    }
                } else if index == points.count {
                    points.append(Point(touchPoint: path.points[index]))
                    if index > 0 {
                        let previousTouchPoint = points[index - 1]
                        let distance = path.points[index].event.location.distance(to: previousTouchPoint.event.location)
                        let elapsed = max(0.0, path.points[index].event.timestamp - previousTouchPoint.event.timestamp)
                        let velocity = elapsed > 0.0 ? distance / elapsed : 0.0
                        points[index].velocity = velocity
                    }
                } else {
                    assertionFailure("Attempting to modify a point that doesn't yet exist. maybe an update is out of order?")
                }
            } else {
                indexesToRemove.insert(index)
            }
        }

        for index in indexesToRemove.reversed() {
            guard index < points.count else {
                print("Error: unknown polyline index \(index)")
                continue
            }
            points.remove(at: index)
        }

        isComplete = path.isComplete

        return indexSet
    }
}

private class BezierBuilder {
    private var elements: [BezierPath.Element] = []
    private let smoother: Smoother
    private(set) var path = BezierPath()

    init(smoother: Smoother) {
        self.smoother = smoother
    }

    @discardableResult
    func update(with line: Polyline, at lineIndexes: MinMaxIndex) -> MinMaxIndex {
        let updatedPathIndexes = smoother.elementIndexes(for: line, at: lineIndexes, with: path)
        guard
            let min = updatedPathIndexes.first,
            let max = updatedPathIndexes.last
        else {
            return updatedPathIndexes
        }
        let updatedPath: BezierPath
        if min - 1 < path.elementCount,
           min - 1 >= 0 {
            updatedPath = path.trimming(to: min - 1)
        } else {
            updatedPath = BezierPath()
        }
        for elementIndex in min ... max {
            assert(elementIndex <= elements.count, "Invalid element index")
            if updatedPathIndexes.contains(elementIndex) {
                if elementIndex > smoother.maxIndex(for: line) {

                } else {
                    let element = smoother.element(for: line, at: elementIndex)
                    if elementIndex == elements.count {
                        elements.append(element)
                    } else {
                        elements[elementIndex] = element
                    }
                    updatedPath.append(element)
                }
            } else {
                // use the existing element
                let element = elements[elementIndex]
                updatedPath.append(element)
            }
        }
        for elementIndex in max + 1 ..< elements.count {
            let element = elements[elementIndex]
            updatedPath.append(element)
        }
        path = updatedPath
        return updatedPathIndexes
    }
}

private class Smoother {
    let smoothFactor: CGFloat

    init(smoothFactor: CGFloat = 1.0) {
        self.smoothFactor = smoothFactor
    }

    func element(for line: Polyline, at elementIndex: Int) -> BezierPath.Element {
        assert(elementIndex >= 0 && elementIndex <= maxIndex(for: line))

        if elementIndex == 0 {
            return BezierPath.Element(type: .moveTo, startPoint: line.points[0], endPoint: line.points[0], controlPoints: [])
        }

        if elementIndex == 1 {
            return Self.newCurve(smoothFactor: smoothFactor,
                                 startPoint: line.points[0],
                                 p1: line.points[0].location,
                                 p2: line.points[1],
                                 p3: line.points[2].location)
        }

        if line.isComplete && elementIndex == maxIndex(for: line) {
            return Self.newCurve(smoothFactor: smoothFactor,
                                 startPoint: line.points[elementIndex - 1],
                                 p0: line.points[elementIndex - 2].location,
                                 p1: line.points[elementIndex - 1].location,
                                 p2: line.points[elementIndex],
                                 p3: line.points[elementIndex].location)
        }

        return Self.newCurve(smoothFactor: smoothFactor,
                             startPoint: line.points[elementIndex - 1],
                             p0: line.points[elementIndex - 2].location,
                             p1: line.points[elementIndex - 1].location,
                             p2: line.points[elementIndex],
                             p3: line.points[elementIndex + 1].location)
    }

    func maxIndex(for line: Polyline) -> Int {
        let lastIndex = line.points.count - 1
        return Swift.max(0, lastIndex - 1) + (line.points.count > 2 && line.isComplete ? 1 : 0)
    }

    func elementIndexes(for line: Polyline, at lineIndexes: MinMaxIndex, with bezier: BezierPath) -> MinMaxIndex {
        var curveIndexes = MinMaxIndex()

        for index in lineIndexes {
            elementIndexes(for: line, at: index, with: bezier, into: &curveIndexes)
        }

        return curveIndexes
    }

    func elementIndexes(for line: Polyline, at lineIndex: Int, with bezier: BezierPath) -> MinMaxIndex {
        var ret = MinMaxIndex()
        elementIndexes(for: line, at: lineIndex, with: bezier, into: &ret)
        return ret
    }

    // Below are the examples of input indexes, and which smoothed elements that point index affects
    // 0 => 2, 1, 0
    // 1 => 3, 2, 1, 0
    // 2 => 4, 3, 2, 1
    // 3 => 5, 4, 3, 2
    // 4 => 6, 5, 4, 3
    // 5 => 7, 6, 5, 4
    // 6 => 8, 7, 6, 5
    // 7 => 9, 8, 7, 6
    private func elementIndexes(for line: Polyline, at lineIndex: Int, with bezier: BezierPath, into indexes: inout MinMaxIndex) {
        guard lineIndex >= 0 else {
            return
        }
        let max = maxIndex(for: line)

        if lineIndex > 1,
           (lineIndex - 1 <= max) || (lineIndex - 1 < bezier.elementCount) {
            indexes.insert(lineIndex - 1)
        }
        if (lineIndex <= max) || (lineIndex < bezier.elementCount) {
            indexes.insert(lineIndex)
        }
        if (lineIndex + 1 <= max) || (lineIndex + 1 < bezier.elementCount) {
            indexes.insert(lineIndex + 1)
        }
        if (lineIndex + 2 <= max) || (lineIndex + 2 < bezier.elementCount) {
            indexes.insert(lineIndex + 2)
        }
    }

    // MARK: - Helper

    private static func newCurve(
        smoothFactor: CGFloat,
        startPoint: Polyline.Point,
        p0: CGPoint? = nil,
        p1: CGPoint,
        p2: Polyline.Point,
        p3: CGPoint
    ) -> BezierPath.Element {
        let p0 = p0 ?? p1

        let c1 = CGPoint(x: (p0.x + p1.x) / 2.0, y: (p0.y + p1.y) / 2.0)
        let c2 = CGPoint(x: (p1.x + p2.x) / 2.0, y: (p1.y + p2.y) / 2.0)
        let c3 = CGPoint(x: (p2.x + p3.x) / 2.0, y: (p2.y + p3.y) / 2.0)

        let len1 = sqrt((p1.x - p0.x) * (p1.x - p0.x) + (p1.y - p0.y) * (p1.y - p0.y))
        let len2 = sqrt((p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y))
        let len3 = sqrt((p3.x - p2.x) * (p3.x - p2.x) + (p3.y - p2.y) * (p3.y - p2.y))

        let k1 = len1 / (len1 + len2)
        let k2 = len2 / (len2 + len3)

        let m1 = CGPoint(x: c1.x + (c2.x - c1.x) * k1, y: c1.y + (c2.y - c1.y) * k1)
        let m2 = CGPoint(x: c2.x + (c3.x - c2.x) * k2, y: c2.y + (c3.y - c2.y) * k2)

        // Resulting control points. Here smooth_value is mentioned
        // above coefficient K whose value should be in range [0...1].
        var ctrl1 = CGPoint(x: m1.x + (c2.x - m1.x) * smoothFactor + p1.x - m1.x,
                              y: m1.y + (c2.y - m1.y) * smoothFactor + p1.y - m1.y)

        var ctrl2 = CGPoint(x: m2.x + (c2.x - m2.x) * smoothFactor + p2.x - m2.x,
                            y: m2.y + (c2.y - m2.y) * smoothFactor + p2.y - m2.y)

        if ctrl1.x.isNaN || ctrl1.y.isNaN {
            ctrl1 = p1
        }

        if ctrl2.x.isNaN || ctrl2.y.isNaN {
            ctrl2 = p2.location
        }

        return BezierPath.Element(type: .cubicCurve, startPoint: startPoint, endPoint: p2, controlPoints: [ctrl1, ctrl2])
    }
}

