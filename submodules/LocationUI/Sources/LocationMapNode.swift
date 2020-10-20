import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import MapKit

let defaultMapSpan = MKCoordinateSpan(latitudeDelta: 0.016, longitudeDelta: 0.016)
let viewMapSpan = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
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

private func generateProximityDim(size: CGSize, rect: CGRect) -> UIImage {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.4).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        
        context.setBlendMode(.clear)
        context.fillEllipse(in: rect)
    })!
}

final class LocationMapNode: ASDisplayNode, MKMapViewDelegate {
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
    
    class InvertedProximityCircle: NSObject, MKOverlay {
        var coordinate: CLLocationCoordinate2D
        var radius: Double
        var alpha: CGFloat {
            didSet {
                self.alphaTransition = (oldValue, CACurrentMediaTime(), 0.3)
            }
        }
        var alphaTransition: (from: CGFloat, startTimestamp: Double, duration: Double)?
        
        var boundingMapRect: MKMapRect {
            return MKMapRect.world
        }
        
        init(center coord: CLLocationCoordinate2D, radius: Double, alpha: CGFloat = 0.0) {
            self.coordinate = coord
            self.radius = radius
            self.alpha = alpha
        }
    }
    
    class InvertedProximityCircleRenderer: MKOverlayRenderer {
        var radius: Double = 0.0
        var fillColor: UIColor = UIColor(rgb: 0x000000, alpha: 0.4)
        
        override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
            guard let overlay = self.overlay as? InvertedProximityCircle else {
                return
            }
            
            var alpha: CGFloat = overlay.alpha
            if let transition = overlay.alphaTransition {
                var t = (CACurrentMediaTime() - transition.startTimestamp) / transition.duration
                t = min(1.0, max(0.0, t))
                alpha = transition.from + (alpha - transition.from) * CGFloat(t)
            }
            
            context.setAlpha(alpha)
            
            let path = UIBezierPath(rect: CGRect(x: mapRect.origin.x, y: mapRect.origin.y, width: mapRect.size.width, height: mapRect.size.height))
            let radiusInMap = overlay.radius * MKMapPointsPerMeterAtLatitude(overlay.coordinate.latitude)
            let mapSize: MKMapSize = MKMapSize(width: radiusInMap, height: radiusInMap)
            let regionOrigin = MKMapPoint(overlay.coordinate)
            var regionRect: MKMapRect = MKMapRect(origin: regionOrigin, size: mapSize)
            regionRect = regionRect.offsetBy(dx: -radiusInMap / 2.0, dy: -radiusInMap / 2.0);
            regionRect = regionRect.intersection(MKMapRect.world);
            
            let excludePath: UIBezierPath = UIBezierPath(roundedRect: CGRect(x: regionRect.origin.x, y: regionRect.origin.y, width: regionRect.size.width, height: regionRect.size.height), cornerRadius: CGFloat(regionRect.size.width) / 2.0)
            path.append(excludePath)
            
            context.setFillColor(fillColor.cgColor);
            context.addPath(path.cgPath);
            context.fillPath(using: .evenOdd)
        }
    }
    private weak var currentInvertedCircleRenderer: InvertedProximityCircleRenderer?
    
    private let locationPromise = Promise<CLLocation?>(nil)
    
    private let pickerAnnotationContainerView: PickerAnnotationContainerView
    private weak var userLocationAnnotationView: MKAnnotationView?
    private var headingArrowView: UIImageView?
    
    private let pinDisposable = MetaDisposable()
    
    private var mapView: LocationMapView? {
        return self.view as? LocationMapView
    }
    
    var returnedToUserLocation = true
    var ignoreRegionChanges = false
    var isDragging = false
    var beganInteractiveDragging: (() -> Void)?
    var endedInteractiveDragging: ((CLLocationCoordinate2D) -> Void)?
    
    var annotationSelected: ((LocationPinAnnotation?) -> Void)?
    var userLocationAnnotationSelected: (() -> Void)?
        
    var indicatorOverlay: InvertedProximityCircle?
    var proximityIndicatorRadius: Double? {
        didSet {
            if let activeProximityRadius = self.proximityIndicatorRadius {
                if let location = self.currentUserLocation, activeProximityRadius != oldValue {
                    let indicatorOverlay: InvertedProximityCircle
                    if let current = self.indicatorOverlay {
                        indicatorOverlay = current
                        indicatorOverlay.radius = activeProximityRadius
                        self.mapView?.removeOverlay(indicatorOverlay)
                        self.mapView?.addOverlay(indicatorOverlay)
                    } else {
                        indicatorOverlay = InvertedProximityCircle(center: location.coordinate, radius: activeProximityRadius)
                        self.mapView?.addOverlay(indicatorOverlay)
                        self.indicatorOverlay = indicatorOverlay
                        indicatorOverlay.alpha = 1.0
                        self.updateAnimations()
                    }
                }
            } else {
                if let indicatorOverlay = self.indicatorOverlay {
                    indicatorOverlay.alpha = 0.0
                    self.updateAnimations()
                }
            }
        }
    }
    
    private var animator: ConstantDisplayLinkAnimator?
    private func updateAnimations() {
        guard let mapView = self.mapView else {
            return
        }
        
        var animate = false
        let timestamp = CACurrentMediaTime()
        
        if let indicatorOverlay = self.indicatorOverlay, let transition = indicatorOverlay.alphaTransition {
            if transition.startTimestamp + transition.duration < timestamp {
                indicatorOverlay.alphaTransition = nil
                if indicatorOverlay.alpha.isZero {
                    self.indicatorOverlay = nil
                    mapView.removeOverlay(indicatorOverlay)
                }
            } else {
                animate = true
            }
        }
        
        if animate {
            let animator: ConstantDisplayLinkAnimator
            if let current = self.animator {
                animator = current
            } else {
                animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateAnimations()
                })
                self.animator = animator
            }
            animator.isPaused = false
        } else {
            self.animator?.isPaused = true
        }
        
        self.currentInvertedCircleRenderer?.setNeedsDisplay(MKMapRect.world)
    }
    
    private var circleOverlay: MKCircle?
    var activeProximityRadius: Double? {
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
        
    override init() {
        self.pickerAnnotationContainerView = PickerAnnotationContainerView()
        self.pickerAnnotationContainerView.isHidden = true
        
        super.init()
        
        self.setViewBlock({
            return LocationMapView()
        })
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.headingArrowView = UIImageView()
        self.headingArrowView?.frame = CGRect(origin: CGPoint(), size: CGSize(width: 88.0, height: 88.0))
        self.headingArrowView?.image = generateHeadingArrowImage()
        
        self.mapView?.interactiveTransitionGestureRecognizerTest = { p in
            if p.x > 44.0 {
                return true
            } else {
                return false
            }
        }
        self.mapView?.delegate = self
        self.mapView?.mapType = self.mapMode.mapType
        self.mapView?.isRotateEnabled = self.isRotateEnabled
        self.mapView?.showsUserLocation = true
        self.mapView?.showsPointsOfInterest = false
        self.mapView?.customHitTest = { [weak self] point in
            guard let strongSelf = self, let annotationView = strongSelf.customUserLocationAnnotationView else {
                return false
            }
            
            if let annotationRect = annotationView.superview?.convert(annotationView.frame.insetBy(dx: -16.0, dy: -16.0), to: strongSelf.mapView), annotationRect.contains(point) {
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
    
    func setMapCenter(coordinate: CLLocationCoordinate2D, span: MKCoordinateSpan = defaultMapSpan, offset: CGPoint = CGPoint(), isUserLocation: Bool = false, hidePicker: Bool = false, animated: Bool = false) {
        let region = MKCoordinateRegion(center: coordinate, span: span)
        self.ignoreRegionChanges = true
        if offset == CGPoint() {
            self.mapView?.setRegion(region, animated: animated)
        } else {
            let mapRect = MKMapRect(region: region)
            self.mapView?.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: offset.y, left: offset.x, bottom: 0.0, right: 0.0), animated: animated)
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
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
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
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
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
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let location = userLocation.location else {
            return
        }
        userLocation.title = ""
        self.locationPromise.set(.single(location))
    }
    
    func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
        self.locationPromise.set(.single(nil))
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for view in views {
            if view.annotation is MKUserLocation {
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
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
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
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
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
        
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let invertedCircle = overlay as? InvertedProximityCircle {
            let renderer = InvertedProximityCircleRenderer(overlay: invertedCircle)
            self.currentInvertedCircleRenderer = renderer
            return renderer
        } else if let circle = overlay as? MKCircle {
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
    
    func mapView(_ mapView: MKMapView, didAdd renderers: [MKOverlayRenderer]) {
        for renderer in renderers {
            if let renderer = renderer as? InvertedProximityCircleRenderer {
                renderer.alpha = 0.0
                UIView.animate(withDuration: 0.3) {
                    renderer.alpha = 1.0
                }
            }
        }
    }
        
    var distancesToAllAnnotations: Signal<[Double], NoError> {
        let poll = Signal<[LocationPinAnnotation], NoError> { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext(strongSelf.annotations)
            }
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let annotationsPoll = (poll |> then(.complete() |> delay(3.0, queue: Queue.concurrentDefaultQueue()))) |> restart
        
        return combineLatest(self.userLocation, annotationsPoll)
        |> map { userLocation, annotations -> [Double] in
            var distances: [Double] = []
            if let userLocation = userLocation {
                for annotation in annotations {
                    distances.append(userLocation.distance(from: CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)))
                }
            }
            return distances.sorted()
        }
    }
    
    var currentUserLocation: CLLocation? {
        return self.mapView?.userLocation.location
    }
    
    var userLocation: Signal<CLLocation?, NoError> {
        return self.locationPromise.get()
    }
    
    var mapCenterCoordinate: CLLocationCoordinate2D? {
        guard let mapView = self.mapView else {
            return nil
        }
        return mapView.convert(CGPoint(x: (mapView.frame.width + pinOffset.x) / 2.0, y: (mapView.frame.height + pinOffset.y) / 2.0), toCoordinateFrom: mapView)
    }
    
    var mapSpan: MKCoordinateSpan? {
        guard let mapView = self.mapView else {
            return nil
        }
        return mapView.region.span
    }
    
    func resetAnnotationSelection() {
        guard let mapView = self.mapView else {
            return
        }
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: true)
        }
    }
    
    var pickerAnnotationView: LocationPinAnnotationView? = nil
    var hasPickerAnnotation: Bool = false {
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
    
    func switchToPicking(raise: Bool = false, animated: Bool) {
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
    
    var customUserLocationAnnotationView: LocationPinAnnotationView? = nil
    var userLocationAnnotation: LocationPinAnnotation? = nil {
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
    
    var userHeading: CGFloat? = nil {
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
    
    var annotations: [LocationPinAnnotation] = [] {
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
                    UIView.animate(withDuration: 0.2) {
                        annotation.coordinate = updatedAnnotation.coordinate
                    }
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
    
    func showAll(animated: Bool = true) {
        guard let mapView = self.mapView else {
            return
        }
        var annotations: [MKAnnotation] = []
        if let userAnnotation = self.userLocationAnnotation {
            annotations.append(userAnnotation)
        }
        annotations.append(contentsOf: self.annotations)
        
        var zoomRect: MKMapRect = MKMapRect()
        for annotation in annotations {
            let pointRegionRect = MKMapRect(region: MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 100, longitudinalMeters: 100))
            zoomRect = zoomRect.union(pointRegionRect)
        }
        
        let insets = UIEdgeInsets()
        zoomRect = mapView.mapRectThatFits(zoomRect, edgePadding: insets)
        mapView.setVisibleMapRect(zoomRect, animated: animated)
    }
    
    func updateLayout(size: CGSize) {
        self.pickerAnnotationContainerView.frame = CGRect(x: 0.0, y: floorToScreenPixels((size.height - size.width) / 2.0), width: size.width, height: size.width)
        if let pickerAnnotationView = self.pickerAnnotationView {
            pickerAnnotationView.center = CGPoint(x: self.pickerAnnotationContainerView.frame.width / 2.0, y: self.pickerAnnotationContainerView.frame.height / 2.0)
        }
    }
}
