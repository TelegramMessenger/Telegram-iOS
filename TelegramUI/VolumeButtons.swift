import Foundation
import UIKit
import SwiftSignalKit
import MediaPlayer

private let minVolume = 0.00001
private let maxVolume = 0.99999

class VolumeChangeDetector: NSObject {
    private let control: MPVolumeView
    private var observer: Any?
    private var currentValue: Float
    
    init(view: UIView, valueChanged: @escaping () -> Void) {
        self.control = MPVolumeView(frame: CGRect(origin: CGPoint(x: -100.0, y: -100.0), size: CGSize(width: 100.0, height: 20.0)))
        self.control.alpha = 0.0001
        self.control.isUserInteractionEnabled = false
        self.control.showsRouteButton = false
        self.currentValue = AVAudioSession.sharedInstance().outputVolume
        
        super.init()
        
        self.observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"), object: nil, queue: OperationQueue.main, using: { [weak self] notification in
            if let strongSelf = self, let userInfo = notification.userInfo {
                if let volume = userInfo["AVSystemController_AudioVolumeNotificationParameter"] as? Float {
                    let previous = strongSelf.currentValue
                    if !previous.isEqual(to: volume) {
                        strongSelf.currentValue = volume

                        var ignore = false
                        if let reason = userInfo["AVSystemController_AudioVolumeChangeReasonNotificationParameter"], reason as? String != "ExplicitVolumeChange" {
                            ignore = true
                        }
                        
                        if !ignore {
                            valueChanged()
                        }
                    }
                    strongSelf.fixVolume()
                }
            }
        })
        
        view.addSubview(self.control)
        
        Queue.mainQueue().after(0.3) {
            self.fixVolume()
        }
    }
    
    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        self.control.removeFromSuperview()
    }
    
    private func fixVolume() {
        for view in self.control.subviews {
            if let slider = view as? UISlider {
                if slider.value == 0.0 { slider.value = Float(minVolume) }
                if slider.value == 1.0 { slider.value = Float(maxVolume) }
            }
        }
    }
}
