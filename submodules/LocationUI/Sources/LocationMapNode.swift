import Foundation
import Display
import SwiftSignalKit
import MapKit

let defaultMapSpan = MKCoordinateSpan(latitudeDelta: 0.016, longitudeDelta: 0.016)
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

final class LocationMapNode: ASDisplayNode, MKMapViewDelegate {
    private let locationPromise = Promise<CLLocation?>(nil)
    
    private let pickerAnnotationContainerView: PickerAnnotationContainerView
    private weak var userLocationAnnotationView: MKAnnotationView?
    
    private var mapView: MKMapView? {
        return self.view as? MKMapView
    }
    
    var ignoreRegionChanges = false
    var isDragging = false
    var beganInteractiveDragging: (() -> Void)?
    var endedInteractiveDragging: ((CLLocationCoordinate2D) -> Void)?
    var annotationSelected: ((LocationPinAnnotation?) -> Void)?
    
    override init() {
        self.pickerAnnotationContainerView = PickerAnnotationContainerView()
        self.pickerAnnotationContainerView.isHidden = true
        
        super.init()
        
        self.setViewBlock({
            return MKMapView()
        })
    }
    
    override func didLoad() {
        super.didLoad()
        
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
    
    func setMapCenter(coordinate: CLLocationCoordinate2D, span: MKCoordinateSpan = defaultMapSpan, offset: CGPoint = CGPoint(), isUserLocation: Bool = false, animated: Bool = false) {
        let region = MKCoordinateRegion(center: coordinate, span: span)
        self.ignoreRegionChanges = true
        if offset == CGPoint() {
            self.mapView?.setRegion(region, animated: animated)
        } else {
            let mapRect = MKMapRect(region: region)
            self.mapView?.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: offset.y, left: offset.x, bottom: 0.0, right: 0.0), animated: animated)
        }
         self.ignoreRegionChanges = false
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        guard !self.ignoreRegionChanges, let scrollView = mapView.subviews.first, let gestureRecognizers = scrollView.gestureRecognizers else {
            return
        }
        
        for gestureRecognizer in gestureRecognizers {
            if gestureRecognizer.state == .began || gestureRecognizer.state == .ended {
                self.isDragging = true
                self.beganInteractiveDragging?()
                
                if self.hasPickerAnnotation {
                    self.customUserLocationAnnotationView?.isHidden = true
                    self.pickerAnnotationContainerView.isHidden = false
                    self.pickerAnnotationView?.setCustom(true, animated: true)
                    self.resetAnnotationSelection()
                }
                break
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if self.isDragging, let coordinate = self.mapCenterCoordinate {
            self.isDragging = false
            self.endedInteractiveDragging?(coordinate)
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
                if let annotationView = self.customUserLocationAnnotationView {
                    view.addSubview(annotationView)
                }
            } else if let view = view as? LocationPinAnnotationView {
                view.setZPosition(-1.0)
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
                view.setZPosition(-1.0)
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
    
    var userLocation: Signal<CLLocation?, NoError> {
        return self.locationPromise.get()
    }
    
    var mapCenterCoordinate: CLLocationCoordinate2D? {
        guard let mapView = self.mapView else {
            return nil
        }
        return mapView.convert(CGPoint(x: (mapView.frame.width + pinOffset.x) / 2.0, y: (mapView.frame.height + pinOffset.y) / 2.0), toCoordinateFrom: mapView)
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
    
    var customUserLocationAnnotationView: LocationPinAnnotationView? = nil
    var userLocationAnnotation: LocationPinAnnotation? = nil {
        didSet {
            if let annotation = self.userLocationAnnotation {
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
    
    var annotations: [LocationPinAnnotation] = [] {
        didSet {
            guard let mapView = self.mapView else {
                return
            }
            
            var dict: [String: LocationPinAnnotation] = [:]
            for annotation in self.annotations {
                if let identifier = annotation.location?.venue?.id {
                    dict[identifier] = annotation
                }
            }
            
            var annotationsToRemove = Set<LocationPinAnnotation>()
            for annotation in mapView.annotations {
                guard let annotation = annotation as? LocationPinAnnotation else {
                    continue
                }
                
                if let identifier = annotation.location?.venue?.id, let updatedAnnotation = dict[identifier] {
                    annotation.coordinate = updatedAnnotation.coordinate
                    dict[identifier] = nil
                } else {
                    annotationsToRemove.insert(annotation)
                }
            }
            
            mapView.removeAnnotations(Array(annotationsToRemove))
            mapView.addAnnotations(Array(dict.values))
        }
    }
    
    override func layout() {
        super.layout()
        
        self.pickerAnnotationContainerView.frame = CGRect(x: 0.0, y: floorToScreenPixels((self.frame.size.height - self.frame.size.width) / 2.0), width: self.frame.size.width, height: self.frame.size.width)
        if let pickerAnnotationView = self.pickerAnnotationView {
            pickerAnnotationView.center = CGPoint(x: self.pickerAnnotationContainerView.frame.width / 2.0, y: self.pickerAnnotationContainerView.frame.height / 2.0 + 16.0)
        }
    }
}
