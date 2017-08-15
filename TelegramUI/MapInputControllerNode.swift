import Foundation
import Display
import AsyncDisplayKit
import MapKit

private var previousUserLocation: CLLocation?

final class MapInputControllerNode: ASDisplayNode, MKMapViewDelegate {
    var dismiss: () -> Void = { }
    
    let locationManager: CLLocationManager
    let mapView: MKMapView
    
    override init() {
        self.locationManager = CLLocationManager()
        self.mapView = MKMapView()
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = UIColor.white
        
        self.mapView.delegate = self
        self.view.addSubview(self.mapView)
        
        if let location = previousUserLocation {
            let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 1000.0 * 2.0, 1000.0 * 2.0)
            mapView.setRegion(coordinateRegion, animated: true)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.mapView.frame = CGRect(origin: CGPoint(), size: layout.size)
    }
    
    func animateIn() {
        self.checkLocationAuthorizationStatus()
        
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut() {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        })
    }
    
    private func checkLocationAuthorizationStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if let location = userLocation.location {
            previousUserLocation = location
            
            let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 1000.0 * 2.0, 1000.0 * 2.0)
            mapView.setRegion(coordinateRegion, animated: true)
        }
    }
}
