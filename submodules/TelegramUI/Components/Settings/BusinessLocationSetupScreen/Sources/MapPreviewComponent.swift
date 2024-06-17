import Foundation
import UIKit
import Display
import ComponentFlow
import ListSectionComponent
import MapKit
import TelegramPresentationData
import AppBundle

final class MapPreviewComponent: Component {
    struct Location: Equatable {
        var latitude: Double
        var longitude: Double
        
        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }
    
    let theme: PresentationTheme
    let location: Location
    let action: (() -> Void)?
    
    init(
        theme: PresentationTheme,
        location: Location,
        action: (() -> Void)? = nil
    ) {
        self.theme = theme
        self.location = location
        self.action = action
    }

    static func ==(lhs: MapPreviewComponent, rhs: MapPreviewComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.location != rhs.location {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton, ListSectionComponent.ChildView {
        private var component: MapPreviewComponent?
        private weak var componentState: EmptyComponentState?
        
        private var mapView: MKMapView?
        
        private let pinShadowView: UIImageView
        private let pinView: UIImageView
        private let pinForegroundView: UIImageView
        
        var customUpdateIsHighlighted: ((Bool) -> Void)?
        private(set) var separatorInset: CGFloat = 0.0
        
        override init(frame: CGRect) {
            self.pinShadowView = UIImageView()
            self.pinView = UIImageView()
            self.pinForegroundView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.pinShadowView)
            self.addSubview(self.pinView)
            self.addSubview(self.pinForegroundView)
            
            self.pinShadowView.image = UIImage(bundleImageName: "Chat/Message/LocationPinShadow")
            self.pinView.image = UIImage(bundleImageName: "Chat/Message/LocationPinBackground")?.withRenderingMode(.alwaysTemplate)
            self.pinForegroundView.image = UIImage(bundleImageName: "Chat/Message/LocationPinForeground")?.withRenderingMode(.alwaysTemplate)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.action?()
        }
        
        func update(component: MapPreviewComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.componentState = state
            
            self.isEnabled = component.action != nil

            let size = CGSize(width: availableSize.width, height: 160.0)
            
            let mapView: MKMapView
            if let current = self.mapView {
                mapView = current
            } else {
                mapView = MKMapView()
                mapView.isUserInteractionEnabled = false
                self.mapView = mapView
                self.insertSubview(mapView, at: 0)
            }
            transition.setFrame(view: mapView, frame: CGRect(origin: CGPoint(), size: size))
            
            let defaultMapSpan = MKCoordinateSpan(latitudeDelta: 0.016, longitudeDelta: 0.016)
            
            let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: component.location.latitude, longitude: component.location.longitude), span: defaultMapSpan)
            if previousComponent?.location != component.location {
                mapView.setRegion(region, animated: false)
                mapView.setVisibleMapRect(mapView.visibleMapRect, edgePadding: UIEdgeInsets(top: 70.0, left: 0.0, bottom: 0.0, right: 0.0), animated: true)
            }
            
            let pinImageSize = self.pinView.image?.size ?? CGSize(width: 62.0, height: 74.0)
            let pinFrame = CGRect(origin: CGPoint(x: floor((size.width - pinImageSize.width) * 0.5), y: floor((size.height - pinImageSize.height) * 0.5)), size: pinImageSize)
            transition.setFrame(view: self.pinShadowView, frame: pinFrame)
            
            transition.setFrame(view: self.pinView, frame: pinFrame)
            self.pinView.tintColor = component.theme.list.itemCheckColors.fillColor
            
            if let image = pinForegroundView.image {
                let pinIconFrame = CGRect(origin: CGPoint(x: pinFrame.minX + floor((pinFrame.width - image.size.width) * 0.5), y: pinFrame.minY + 15.0), size: image.size)
                transition.setFrame(view: self.pinForegroundView, frame: pinIconFrame)
                self.pinForegroundView.tintColor = component.theme.list.itemCheckColors.foregroundColor
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
