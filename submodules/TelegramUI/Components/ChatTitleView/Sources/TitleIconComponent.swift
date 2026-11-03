import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

final class TitleIconComponent: Component {
    enum Kind {
        case mute
        case lock
    }
    
    let kind: Kind
    let color: UIColor
    
    init(
        kind: Kind,
        color: UIColor
    ) {
        self.kind = kind
        self.color = color
    }
    
    static func ==(lhs: TitleIconComponent, rhs: TitleIconComponent) -> Bool {
        if lhs.kind != rhs.kind {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let iconView: UIImageView
        
        var component: TitleIconComponent?
        
        override init(frame: CGRect) {
            self.iconView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: TitleIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component?.kind != component.kind {
                switch component.kind {
                case .mute:
                    self.iconView.image = generateImage(CGSize(width: 9.0, height: 9.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(UIColor.white.cgColor)
                        
                        let _ = try? drawSvgPath(context, path: "M2.97607626,2.27306995 L5.1424026,0.18411241 C5.25492443,0.0756092198 5.40753677,0.0146527621 5.56666667,0.0146527621 C5.89803752,0.0146527621 6.16666667,0.273688014 6.16666667,0.593224191 L6.16666667,5.47790407 L8.86069303,8.18395735 C9.05193038,8.37604845 9.04547086,8.68126082 8.84626528,8.86566828 C8.6470597,9.05007573 8.33054317,9.0438469 8.13930581,8.85175581 L0.139306972,0.816042647 C-0.0519303838,0.623951552 -0.0454708626,0.318739175 0.153734717,0.134331724 C0.352940296,-0.0500757275 0.669456833,-0.0438469035 0.860694189,0.148244192 L2.97607626,2.27306995 Z M0.933196438,2.75856564 L6.16666667,8.01539958 L6.16666667,8.40677707 C6.16666667,8.56022375 6.10345256,8.70738566 5.99093074,8.81588885 C5.75661616,9.04183505 5.37671717,9.04183505 5.1424026,8.81588885 L2.59763107,6.36200202 C2.53511895,6.30172247 2.45033431,6.26785777 2.36192881,6.26785777 L1.16666667,6.26785777 C0.614381917,6.26785777 0.166666667,5.83613235 0.166666667,5.30357206 L0.166666667,3.6964292 C0.166666667,3.24138962 0.493527341,2.85996592 0.933196438,2.75856564 Z ")
                    })?.withRenderingMode(.alwaysTemplate)
                case .lock:
                    self.iconView.image = generateImage(CGSize(width: 9.0, height: 13.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        
                        context.translateBy(x: 0.0, y: 1.0)
                        
                        context.setFillColor(UIColor.white.cgColor)
                        context.setStrokeColor(UIColor.white.cgColor)
                        context.setLineWidth(1.32)
                        
                        let _ = try? drawSvgPath(context, path: "M4.5,0.600000024 C5.88071187,0.600000024 7,1.88484952 7,3.46979169 L7,7.39687502 C7,8.9818172 5.88071187,10.2666667 4.5,10.2666667 C3.11928813,10.2666667 2,8.9818172 2,7.39687502 L2,3.46979169 C2,1.88484952 3.11928813,0.600000024 4.5,0.600000024 S ")
                        let _ = try? drawSvgPath(context, path: "M1.32,5.65999985 L7.68,5.65999985 C8.40901587,5.65999985 9,6.25098398 9,6.97999985 L9,10.6733332 C9,11.4023491 8.40901587,11.9933332 7.68,11.9933332 L1.32,11.9933332 C0.59098413,11.9933332 1.11022302e-16,11.4023491 0,10.6733332 L2.22044605e-16,6.97999985 C1.11022302e-16,6.25098398 0.59098413,5.65999985 1.32,5.65999985 Z ")
                    })?.withRenderingMode(.alwaysTemplate)
                }
            }
            
            let size = CGSize(width: 14.0, height: 14.0)
            
            if let image = self.iconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) * 0.5), y: floorToScreenPixels((size.height - image.size.height) * 0.5)), size: image.size)
                self.iconView.frame = iconFrame
            }
            self.iconView.tintColor = component.color
            
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
