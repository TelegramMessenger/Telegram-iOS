import Foundation
import UIKit
import ComponentFlow
import AccountContext

final class MediaStreamVideoComponent: Component {
    let call: PresentationGroupCallImpl
    
    init(call: PresentationGroupCallImpl) {
        self.call = call
    }
    
    public static func ==(lhs: MediaStreamVideoComponent, rhs: MediaStreamVideoComponent) -> Bool {
        if lhs.call !== rhs.call {
            return false
        }
        
        return true
    }
    
    public final class View: UIView {
        private let videoRenderingContext = VideoRenderingContext()
        private var videoView: VideoRenderingView?
        
        func update(component: MediaStreamVideoComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if self.videoView == nil {
                if let input = component.call.video(endpointId: "unified") {
                    if let videoView = self.videoRenderingContext.makeView(input: input, blur: false) {
                        self.videoView = videoView
                        self.addSubview(videoView)
                    }
                }
            }
            
            if let videoView = self.videoView {
                videoView.updateIsEnabled(true)
                videoView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
