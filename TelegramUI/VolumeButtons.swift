import Foundation
import UIKit
import SwiftSignalKit
import MediaPlayer

private let minVolume: Float = 0.0001
private let maxVolume: Float = 0.9999

private let delay = 0.4

class VolumeButtonsListener: NSObject {
    private weak var superview: UIView?
    
    private let control: MPVolumeView
    private var observer: Any?
    private var currentValue: Float
    
    private var ignoreUntil: CFTimeInterval?
    
    private var disposable: Disposable?
    
    init(view: UIView, shouldBeActive: Signal<Bool, NoError>, valueChanged: @escaping () -> Void) {
        self.superview = view
        
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
                        
                        if let ignoreUntil = strongSelf.ignoreUntil, CACurrentMediaTime() < ignoreUntil {
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
        
        self.disposable = (shouldBeActive
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if value {
                if strongSelf.control.superview == nil {
                    strongSelf.ignoreUntil = CACurrentMediaTime() + delay * 2.0
                    strongSelf.superview?.addSubview(strongSelf.control)
                    
                    Queue.mainQueue().after(delay) {
                        strongSelf.fixVolume()
                    }
                }
            } else {
                strongSelf.control.removeFromSuperview()
            }
        })
    }
    
    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        self.control.removeFromSuperview()
        self.disposable?.dispose()
    }
    
    private func fixVolume() {
        for view in self.control.subviews {
            if let slider = view as? UISlider {
                if slider.value == 1.0 {
                    slider.value = maxVolume
                    self.currentValue = maxVolume
                }
            }
        }
    }
}
