import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import MapKit

private let pinOffset = CGPoint(x: 0.0, y: 33.0)

public enum LocationMapMode {
    case map
    case sattelite
    case hybrid
    
    var mapType: MKMapType {
        switch self {
            case .sattelite:
                return .satellite
            case .hybrid:
                return .hybrid
            default:
                return .standard
        }
    }
}

public enum LocationTrackingMode {
    case none
    case follow
    case followWithHeading
    
    var userTrackingMode: MKUserTrackingMode {
        switch self {
            case .follow:
                return .follow
            case .followWithHeading:
                return .followWithHeading
            default:
                return .none
        }
    }
}

private class PickerAnnotationContainerView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result == self {
            return nil
        }
        return result
    }
}

private class LocationMapView: MKMapView, UIGestureRecognizerDelegate {
    var customHitTest: ((CGPoint) -> Bool)?
    private var allowSelectionChanges = true
    
    @objc override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let customHitTest = self.customHitTest, customHitTest(gestureRecognizer.location(in: self)) {
            return false
        }
        return self.allowSelectionChanges
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let pointInside = super.point(inside: point, with: event)
        if !pointInside {
            return pointInside
        }
        
        for annotation in self.annotations(in: self.visibleMapRect) where annotation is LocationPinAnnotation {
            guard let view = self.view(for: annotation as! MKAnnotation) else {
                continue
            }
            if view.frame.insetBy(dx: -16.0, dy: -16.0).contains(point) {
                self.allowSelectionChanges = true
                return true
            }
        }
        self.allowSelectionChanges = false
        
        return pointInside
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
    }
}

private let arrowImageSize = CGSize(width: 90.0, height: 90.0)
func generateHeadingArrowImage() -> UIImage? {
    return generateImage(arrowImageSize, contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
    
        context.saveGState()
        let center = CGPoint(x: arrowImageSize.width / 2.0, y: arrowImageSize.height / 2.0)
        context.move(to: center)
        context.addArc(center: center, radius: arrowImageSize.width / 2.0, startAngle: CGFloat.pi / 2.0 + CGFloat.pi / 8.0, endAngle: CGFloat.pi / 2.0 - CGFloat.pi / 8.0, clockwise: true)
        context.clip()
        
        var locations: [CGFloat] = [0.0, 0.4, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0x007aff, alpha: 0.5).cgColor, UIColor(rgb: 0x007aff, alpha: 0.3).cgColor, UIColor(rgb: 0x007aff, alpha: 0.0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 11.0, endCenter: center, endRadius: arrowImageSize.width / 2.0, options: .drawsAfterEndLocation)
        
        context.restoreGState()
        context.setBlendMode(.clear)
        context.fillEllipse(in: CGRect(x: (arrowImageSize.width - 22.0) / 2.0, y: (arrowImageSize.height - 22.0) / 2.0, width: 22.0, height: 22.0))
    })
}

private func generateProximityDim(size: CGSize) -> UIImage {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.4).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        
        context.setBlendMode(.clear)
        
        let ellipseSize = CGSize(width: 260.0, height: 260.0)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: (size.width - ellipseSize.width) / 2.0, y: (size.height - ellipseSize.height) / 2.0), size: ellipseSize))
    })!
}

protocol MKMapViewDelegateTarget: AnyObject {
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool)
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool)
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation)
    func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error)
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView])
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView)
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView)
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer
}

private final class MKMapViewDelegateImpl: NSObject, MKMapViewDelegate {
    private weak var target: MKMapViewDelegateTarget?
    
    init(target: MKMapViewDelegateTarget) {
        self.target = target
        
        super.init()
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        self.target?.mapView(mapView, regionWillChangeAnimated: animated)
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        self.target?.mapView(mapView, regionDidChangeAnimated: animated)
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        self.target?.mapView(mapView, didUpdate: userLocation)
    }
    
    func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
        self.target?.mapView(mapView, didFailToLocateUserWithError: error)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        return self.target?.mapView(mapView, viewFor: annotation)
    }
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        self.target?.mapView(mapView, didAdd: views)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        self.target?.mapView(mapView, didSelect: view)
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        self.target?.mapView(mapView, didDeselect: view)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return self.target?.mapView(mapView, rendererFor: overlay) ?? MKOverlayRenderer()
    }
}

public final class LocationMapNode: ASDisplayNode, MKMapViewDelegateTarget {
    private var delegateImpl: MKMapViewDelegateImpl?
    
    public static let defaultMapSpan = MKCoordinateSpan(latitudeDelta: 0.016, longitudeDelta: 0.016)
    public static let viewMapSpan = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
    public static let globalMapSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    
    class ProximityCircleRenderer: MKCircleRenderer {
        override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
            super.draw(mapRect, zoomScale: zoomScale, in: context)
            
            context.saveGState()
            
            let mapBoundingRect = self.circle.boundingMapRect
            let mapPoint = MKMapPoint(x: mapBoundingRect.midX, y: mapBoundingRect.maxY)
            let drawingPoint = point(for: mapPoint)
            
            if let image = generateTintedImage(image: UIImage(bundleImageName: "Location/ProximityIcon"), color: self.strokeColor ?? .black) {
                let imageSize = CGSize(width: floor(image.size.width / zoomScale * self.contentScaleFactor * 0.75), height: floor(image.size.height / zoomScale * self.contentScaleFactor * 0.75))
                context.translateBy(x: drawingPoint.x, y: drawingPoint.y)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -drawingPoint.x, y: -drawingPoint.y)
                let imageRect = CGRect(x: floor((drawingPoint.x - imageSize.width / 2.0)), y: floor((drawingPoint.y - imageSize.height / 2.0)), width: imageSize.width, height: imageSize.height)
                context.clear(imageRect)
                context.draw(image.cgImage!, in: imageRect)
            }
            context.restoreGState()
        }
    }
        
    private let locationPromise = Promise<CLLocation?>(nil)
    
    private let pickerAnnotationContainerView: PickerAnnotationContainerView
    private weak var userLocationAnnotationView: MKAnnotationView?
    private var headingArrowView: UIImageView?
    private var compassView: MKCompassButton?
    
    private weak var defaultUserLocationAnnotation: MKAnnotation?
    
    private let pinDisposable = MetaDisposable()
    
    private var mapView: LocationMapView? {
        return self.view as? LocationMapView
    }
    
    var returnedToUserLocation = true
    var ignoreRegionChanges = false
    var isDragging = false
    var beganInteractiveDragging: (() -> Void)?
    var endedInteractiveDragging: ((CLLocationCoordinate2D) -> Void)?
    var disableHorizontalTransitionGesture = false
    
    var annotationSelected: ((LocationPinAnnotation?) -> Void)?
    var userLocationAnnotationSelected: (() -> Void)?
            
    var proximityDimView = UIImageView()
    var proximityIndicatorRadius: Double? {
        didSet {
            if let _ = self.proximityIndicatorRadius, let mapView = self.mapView {
                if self.proximityDimView.image == nil {
                    proximityDimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
                
                if oldValue == 0 {
                    UIView.transition(with: proximityDimView, duration: 0.3, options: .transitionCrossDissolve) {
                        self.proximityDimView.image = generateProximityDim(size: mapView.bounds.size)
                    } completion: { _ in
                        
                    }
                }
            } else {
                if self.proximityDimView.image != nil {
                    UIView.transition(with: proximityDimView, duration: 0.3, options: .transitionCrossDissolve) {
                        self.proximityDimView.image = nil
                    } completion: { _ in
                        
                    }
                }
            }
        }
    }
        
    private var circleOverlay: MKCircle?
    public var activeProximityRadius: Double? {
        didSet {
            if let activeProximityRadius = self.activeProximityRadius {
                if let circleOverlay = self.circleOverlay {
                    self.circleOverlay = nil
                    self.mapView?.removeOverlay(circleOverlay)
                }
                if let location = self.currentUserLocation {
                    let overlay = MKCircle(center: location.coordinate, radius: activeProximityRadius)
                    self.circleOverlay = overlay
                    self.mapView?.addOverlay(overlay)
                }
            } else {
                if let circleOverlay = self.circleOverlay {
                    self.circleOverlay = nil
                    self.mapView?.removeOverlay(circleOverlay)
                }
            }
        }
    }
        
    override public init() {
        self.pickerAnnotationContainerView = PickerAnnotationContainerView()
        self.pickerAnnotationContainerView.isHidden = true
        
        super.init()
        
        self.setViewBlock({
            return LocationMapView()
        })
    }
    
    override public func didLoad() {
        super.didLoad()
        
        guard let mapView = self.mapView else {
            return
        }
        
        self.headingArrowView = UIImageView()
        self.headingArrowView?.frame = CGRect(origin: CGPoint(), size: CGSize(width: 88.0, height: 88.0))
        self.headingArrowView?.image = generateHeadingArrowImage()
        
        mapView.interactiveTransitionGestureRecognizerTest = { p in
            if p.x > 44.0 {
                return true
            } else {
                return false
            }
        }
        
        mapView.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            return self?.disableHorizontalTransitionGesture == true
        }
        
        let delegateImpl = MKMapViewDelegateImpl(target: self)
        self.delegateImpl = delegateImpl
        
        let compassView = MKCompassButton(mapView: mapView)
        compassView.isUserInteractionEnabled = true
        self.compassView = compassView
        mapView.addSubview(compassView)
        
        mapView.delegate = delegateImpl
        mapView.mapType = self.mapMode.mapType
        mapView.isRotateEnabled = self.isRotateEnabled
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.customHitTest = { [weak self] point in
            guard let strongSelf = self else {
                return false
            }
            
            if let annotationView = strongSelf.customUserLocationAnnotationView, let annotationRect = annotationView.superview?.convert(annotationView.frame.insetBy(dx: -16.0, dy: -16.0), to: strongSelf.mapView), annotationRect.contains(point) {
                strongSelf.userLocationAnnotationSelected?()
                return true
            }
            
            if let userAnnotation = strongSelf.defaultUserLocationAnnotation, let annotationView = strongSelf.mapView?.view(for: userAnnotation), let annotationRect = annotationView.superview?.convert(annotationView.frame.insetBy(dx: -16.0, dy: -16.0), to: strongSelf.mapView), annotationRect.contains(point) {
                strongSelf.userLocationAnnotationSelected?()
                return true
            }
            
            return false
        }
        self.view.addSubview(self.pickerAnnotationContainerView)
    }
    
    var isRotateEnabled: Bool = true {
        didSet {
            self.mapView?.isRotateEnabled = self.isRotateEnabled
        }
    }
    
    var mapMode: LocationMapMode = .map {
        didSet {
            self.mapView?.mapType = self.mapMode.mapType
        }
    }
    
    public var trackingMode: LocationTrackingMode = .none {
        didSet {
            self.mapView?.userTrackingMode = self.trackingMode.userTrackingMode
            if self.trackingMode == .followWithHeading && self.headingArrowView?.image != nil {
                self.headingArrowView?.image = nil
            } else if self.trackingMode != .followWithHeading && self.headingArrowView?.image == nil {
                self.headingArrowView?.image = generateHeadingArrowImage()
            }
        }
    }
    
    var topPadding: CGFloat = 0.0
    var mapOffset: CGFloat = 0.0
    var hasValidLayout: Bool = false
    var pendingSetMapCenter: (coordinate: CLLocationCoordinate2D, span: MKCoordinateSpan, offset: CGPoint, isUserLocation: Bool, hidePicker: Bool, animated: Bool)?
    
    public func setMapCenter(coordinate: CLLocationCoordinate2D, radius: Double, insets: UIEdgeInsets, offset: CGFloat, animated: Bool = false) {
        self.mapOffset = offset
        self.ignoreRegionChanges = true
        
        var insets = insets
        insets.top += self.topPadding
        
        let mapRect = MKMapRect(region: MKCoordinateRegion(center: coordinate, latitudinalMeters: radius * 2.0, longitudinalMeters: radius * 2.0))
        self.mapView?.setVisibleMapRect(mapRect, edgePadding: insets, animated: animated)
        self.ignoreRegionChanges = false
        
        self.proximityDimView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY + offset)
    }
    
    public func setMapCenter(coordinate: CLLocationCoordinate2D, span: MKCoordinateSpan = defaultMapSpan, offset: CGPoint = CGPoint(), isUserLocation: Bool = false, hidePicker: Bool = false, animated: Bool = false) {
        self.pendingSetMapCenter = (
            coordinate, span, offset, isUserLocation, hidePicker, animated
        )
        
        if self.hasValidLayout {
            self.applyPendingSetMapCenter()
        }
    }
    
    private func applyPendingSetMapCenter() {
        if !self.hasValidLayout {
            return
        }
        guard let (coordinate, span, offset, isUserLocation, hidePicker, animated) = self.pendingSetMapCenter else {
            return
        }
        self.pendingSetMapCenter = nil
        
        let region = MKCoordinateRegion(center: coordinate, span: span)
        self.ignoreRegionChanges = true
        if offset == CGPoint() && self.topPadding == 0.0 {
            self.mapView?.setRegion(region, animated: animated)
        } else {
            let mapRect = MKMapRect(region: region)
            var effectiveTopOffset: CGFloat = offset.y
            if #available(iOS 18.0, *) {
            } else {
                effectiveTopOffset += self.topPadding
            }
            self.mapView?.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: effectiveTopOffset, left: offset.x, bottom: 0.0, right: 0.0), animated: animated)
        }
        self.ignoreRegionChanges = false
        
        if isUserLocation {
            if !self.returnedToUserLocation {
                self.returnedToUserLocation = true
                self.pickerAnnotationView?.setRaised(true, animated: true)
            }
        } else if self.hasPickerAnnotation, let customUserLocationAnnotationView = self.customUserLocationAnnotationView, customUserLocationAnnotationView.isHidden, hidePicker {
            self.pickerAnnotationContainerView.isHidden = true
            customUserLocationAnnotationView.setSelected(false, animated: false)
            customUserLocationAnnotationView.isHidden = false
            customUserLocationAnnotationView.animateAppearance()
        }
    }
    
    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        guard !self.ignoreRegionChanges, let scrollView = mapView.subviews.first, let gestureRecognizers = scrollView.gestureRecognizers else {
            return
        }
        
        for gestureRecognizer in gestureRecognizers {
            if gestureRecognizer.state == .began || gestureRecognizer.state == .ended {
                self.isDragging = true
                self.returnedToUserLocation = false
                self.beganInteractiveDragging?()
                
                self.switchToPicking(raise: true, animated: true)
                break
            }
        }
    }
    
    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let wasDragging = self.isDragging
        if self.isDragging {
            self.isDragging = false
            if let coordinate = self.mapCenterCoordinate {
                self.endedInteractiveDragging?(coordinate)
            }
        }
        
        if let pickerAnnotationView = self.pickerAnnotationView {
            if pickerAnnotationView.isRaised && (wasDragging || self.returnedToUserLocation) {
                self.schedulePin(wasDragging: wasDragging)
            }
        }
    }
    
    public func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let location = userLocation.location else {
            return
        }
        userLocation.title = ""
        self.locationPromise.set(.single(location))
    }
    
    public func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
        self.locationPromise.set(.single(nil))
    }
    
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation === mapView.userLocation {
            return nil
        }
        
        if let annotation = annotation as? LocationPinAnnotation {
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: locationPinReuseIdentifier)
            if view == nil {
                view = LocationPinAnnotationView(annotation: annotation)
            }
            return view
        }
        
        return nil
    }
    
    public func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for view in views {
            if view.annotation is MKUserLocation {
                self.defaultUserLocationAnnotation = view.annotation
                view.canShowCallout = false
                
                self.userLocationAnnotationView = view
                if let headingArrowView = self.headingArrowView {
                    view.addSubview(headingArrowView)
                    headingArrowView.center = CGPoint(x: view.frame.width / 2.0, y: view.frame.height / 2.0)
                }
                if let annotationView = self.customUserLocationAnnotationView {
                    view.addSubview(annotationView)
                }
            } else if let view = view as? LocationPinAnnotationView {
                view.setZPosition(view.defaultZPosition)
            }
            
            if let container = view.superview {
                container.insertSubview(self.proximityDimView, at: 0)
            }
        }
    }
    
    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? LocationPinAnnotation else {
            return
        }
        
        if let view = view as? LocationPinAnnotationView {
            view.setZPosition(nil)
        }
        
        self.annotationSelected?(annotation)
        
        if let annotationView = self.customUserLocationAnnotationView, annotationView.isSelected {
            annotationView.setSelected(false, animated: true)
        }
    }
    
    public func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        if let view = view as? LocationPinAnnotationView {
            Queue.mainQueue().after(0.2) {
                view.setZPosition(view.defaultZPosition)
            }
        }
        
        Queue.mainQueue().after(0.05) {
            if mapView.selectedAnnotations.isEmpty {
                if !self.isDragging {
                    self.annotationSelected?(nil)
                }
                if let annotationView = self.customUserLocationAnnotationView, !annotationView.isSelected {
                    annotationView.setSelected(true, animated: true)
                }
            }
        }
    }
        
    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
            let renderer = ProximityCircleRenderer(circle: circle)
            renderer.fillColor = .clear
            renderer.strokeColor = UIColor(rgb: 0xc3baaf)
            renderer.lineWidth = 0.75
            renderer.lineDashPattern = [5, 4]
            return renderer
        } else {
            return MKOverlayRenderer()
        }
    }
            
    public var distancesToAllAnnotations: Signal<[Double], NoError> {
        let poll = Signal<[LocationPinAnnotation], NoError> { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext(strongSelf.annotations)
            }
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let annotationsPoll = (poll |> then(.complete() |> delay(1.0, queue: Queue.concurrentDefaultQueue()))) |> restart
        
        return combineLatest(self.userLocation, annotationsPoll)
        |> map { userLocation, annotations -> [Double] in
            var distances: [Double] = []
            if let userLocation = userLocation {
                for annotation in annotations {
                    if annotation.isSelf {
                        continue
                    }
                    distances.append(userLocation.distance(from: CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)))
                }
            }
            return distances.sorted()
        }
    }
    
    public var currentUserLocation: CLLocation? {
        return self.mapView?.userLocation.location
    }
    
    public var userLocation: Signal<CLLocation?, NoError> {
        return .single(self.currentUserLocation)
        |> then (self.locationPromise.get())
    }
    
    public var mapCenterCoordinate: CLLocationCoordinate2D? {
        guard let mapView = self.mapView else {
            return nil
        }
        return mapView.convert(CGPoint(x: (mapView.frame.width + pinOffset.x) / 2.0, y: (mapView.frame.height + pinOffset.y) / 2.0), toCoordinateFrom: mapView)
    }
    
    public var mapSpan: MKCoordinateSpan? {
        guard let mapView = self.mapView else {
            return nil
        }
        return mapView.region.span
    }
    
    public func resetAnnotationSelection() {
        guard let mapView = self.mapView else {
            return
        }
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: true)
        }
    }
    
    public var pickerAnnotationView: LocationPinAnnotationView? = nil
    public var hasPickerAnnotation: Bool = false {
        didSet {
            if self.hasPickerAnnotation, let annotation = self.userLocationAnnotation {
                let pickerAnnotationView = LocationPinAnnotationView(annotation: annotation)
                pickerAnnotationView.center = CGPoint(x: self.pickerAnnotationContainerView.frame.width / 2.0, y: self.pickerAnnotationContainerView.frame.height / 2.0 + 16.0)
                self.pickerAnnotationContainerView.addSubview(pickerAnnotationView)
                self.pickerAnnotationView = pickerAnnotationView
            } else {
                self.pickerAnnotationView?.removeFromSuperview()
                self.pickerAnnotationView = nil
            }
        }
    }
    
    public func switchToPicking(raise: Bool = false, animated: Bool) {
        guard self.hasPickerAnnotation else {
            return
        }
        
        self.customUserLocationAnnotationView?.isHidden = true
        self.pickerAnnotationContainerView.isHidden = false
        if let pickerAnnotationView = self.pickerAnnotationView, !pickerAnnotationView.isRaised {
            pickerAnnotationView.setCustom(true, animated: animated)
            if raise {
                pickerAnnotationView.setRaised(true, animated: animated)
            }
        }
        self.resetAnnotationSelection()
        self.resetScheduledPin()
    }
    
    public var customUserLocationAnnotationView: LocationPinAnnotationView? = nil
    public var userLocationAnnotation: LocationPinAnnotation? = nil {
        didSet {
            if let annotation = self.userLocationAnnotation {
                self.customUserLocationAnnotationView?.removeFromSuperview()
                
                let annotationView = LocationPinAnnotationView(annotation: annotation)
                annotationView.frame = annotationView.frame.offsetBy(dx: 21.0, dy: 22.0)
                if let parentView = self.userLocationAnnotationView {
                    parentView.addSubview(annotationView)
                }
                self.customUserLocationAnnotationView = annotationView
                
                self.pickerAnnotationView?.annotation = annotation
            } else {
                self.customUserLocationAnnotationView?.removeFromSuperview()
                self.customUserLocationAnnotationView = nil
            }
        }
    }
    
    public var userHeading: CGFloat? = nil {
        didSet {
            if let heading = self.userHeading {
                self.headingArrowView?.isHidden = false
                self.headingArrowView?.transform = CGAffineTransform(rotationAngle: CGFloat(heading / 180.0 * CGFloat.pi))
            } else {
                self.headingArrowView?.isHidden = true
                self.headingArrowView?.transform = CGAffineTransform.identity
            }
        }
    }
    
    public var annotations: [LocationPinAnnotation] = [] {
        didSet {
            guard let mapView = self.mapView else {
                return
            }
            
            var dict: [String: LocationPinAnnotation] = [:]
            for annotation in self.annotations {
                dict[annotation.id] = annotation
            }
            
            var annotationsToRemove = Set<LocationPinAnnotation>()
            for annotation in mapView.annotations {
                guard let annotation = annotation as? LocationPinAnnotation else {
                    continue
                }
                
                if let updatedAnnotation = dict[annotation.id] {
                    func degToRad(_ degrees: Double) -> Double {
                        return degrees * Double.pi / 180.0
                    }
                    
                    func radToDeg(_ radians: Double) -> Double {
                        return radians / Double.pi * 180.0
                    }

                    let currentCoordinate = annotation.coordinate
                    let coordinate = updatedAnnotation.coordinate
                    var heading = updatedAnnotation.heading
                    if heading == nil {
                        let previous = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
                        let new = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        
                        if new.distance(from: previous) > 10 {
                            let lat1 = degToRad(currentCoordinate.latitude)
                            let lon1 = degToRad(currentCoordinate.longitude)
                            let lat2 = degToRad(coordinate.latitude)
                            let lon2 = degToRad(coordinate.longitude)

                            let dLat = lat2 - lat1
                            let dLon = lon2 - lon1
                            
                            if dLat != 0 && dLon != 0 {
                                let y = sin(dLon) * cos(lat2)
                                let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
                                heading = NSNumber(value: radToDeg(atan2(y, x)))
                            }
                        } else {
                            heading = annotation.heading
                        }
                    }
                    
                    UIView.animate(withDuration: 0.2) {
                        annotation.coordinate = updatedAnnotation.coordinate
                    }
                    
                    annotation.heading = heading
                    dict[annotation.id] = nil
                } else {
                    annotationsToRemove.insert(annotation)
                }
            }
            
            let selectedAnnotation = mapView.selectedAnnotations.first
            var updated = false
            if !annotationsToRemove.isEmpty {
                mapView.removeAnnotations(Array(annotationsToRemove))
                updated = true
            }
            if !dict.isEmpty {
                mapView.addAnnotations(Array(dict.values))
                updated = true
            }
            if let selectedAnnotation = selectedAnnotation as? LocationPinAnnotation, updated {
                for annotation in self.annotations {
                    if annotation.id == selectedAnnotation.id {
                        mapView.selectAnnotation(annotation, animated: false)
                        break
                    }
                }
            }
        }
    }
    
    private func schedulePin(wasDragging: Bool) {
        let timeout: Double = wasDragging ? 0.38 : 0.05
         
         let signal: Signal<Never, NoError> = .complete()
         |> delay(timeout, queue: Queue.mainQueue())
         self.pinDisposable.set(signal.start(completed: { [weak self] in
            guard let strongSelf = self, let pickerAnnotationView = strongSelf.pickerAnnotationView else {
                return
            }
            
            pickerAnnotationView.setRaised(false, animated: true) { [weak self] in
                guard let strongSelf = self else {
                    return
                }
               
                if strongSelf.returnedToUserLocation {
                    strongSelf.pickerAnnotationContainerView.isHidden = true
                    strongSelf.customUserLocationAnnotationView?.isHidden = false
                }
            }
            
            if strongSelf.returnedToUserLocation {
                pickerAnnotationView.setCustom(false, animated: true)
            }
         }))
    }
    
    private func resetScheduledPin() {
        self.pinDisposable.set(nil)
    }
    
    public func showAll(animated: Bool = true) {
        guard let mapView = self.mapView else {
            return
        }
        var coordinates: [CLLocationCoordinate2D] = []
        if let location = self.currentUserLocation {
            coordinates.append(location.coordinate)
        }
        coordinates.append(contentsOf: self.annotations.map { $0.coordinate })
        
        var zoomRect: MKMapRect?
        for coordinate in coordinates {
            let pointRegionRect = MKMapRect(region: MKCoordinateRegion(center: coordinate, latitudinalMeters: 100, longitudinalMeters: 100))
            if let currentZoomRect = zoomRect {
                zoomRect = currentZoomRect.union(pointRegionRect)
            } else {
                zoomRect = pointRegionRect
            }
        }
        
        if let zoomRect = zoomRect {
            let insets = UIEdgeInsets(top: 88.0, left: 80.0, bottom: 160.0, right: 80.0)
            let fittedZoomRect = mapView.mapRectThatFits(zoomRect, edgePadding: insets)
            mapView.setVisibleMapRect(fittedZoomRect, animated: animated)
        }
    }
    
    public func updateLayout(size: CGSize, topPadding: CGFloat, inset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.hasValidLayout = true
        
        self.topPadding = topPadding
        
        self.proximityDimView.frame = CGRect(origin: CGPoint(x: 0.0, y: self.topPadding + self.mapOffset), size: size)
        self.pickerAnnotationContainerView.frame = CGRect(x: 0.0, y: floorToScreenPixels((size.height - size.width) / 2.0), width: size.width, height: size.width)
        if let pickerAnnotationView = self.pickerAnnotationView {
            pickerAnnotationView.center = CGPoint(x: self.pickerAnnotationContainerView.frame.width / 2.0, y: self.pickerAnnotationContainerView.frame.height / 2.0)
        }
        
        if let compassView = self.compassView {
            transition.updateFrame(view: compassView, frame:  CGRect(origin: CGPoint(x: size.width - compassView.frame.width - 11.0, y: inset + 110.0 + topPadding), size: compassView.frame.size))
        }
        
        self.applyPendingSetMapCenter()
    }
}
