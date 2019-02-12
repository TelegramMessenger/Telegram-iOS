import Foundation
import UIKit
import MediaPlayer

private struct Observation {
    static let VolumeKey = "outputVolume"
    static var Context = 0
    
}

class VolumeChangeDetector: NSObject {
    private let control: MPVolumeView
    private var observer: Any?
    private var currentValue: Float
    private var ignoreAdjustmentOnce = false
    
    init(view: UIView, valueChanged: @escaping () -> Void) {
        self.control = MPVolumeView(frame: CGRect(origin: CGPoint(x: 0.0, y: -64.0), size: CGSize(width: 100.0, height: 20.0)))
        self.currentValue = AVAudioSession.sharedInstance().outputVolume
        
        super.init()
        
        self.observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"), object: nil, queue: OperationQueue.main, using: { [weak self] notification in
            if let strongSelf = self, let userInfo = notification.userInfo {
                if let volume = userInfo["AVSystemController_AudioVolumeNotificationParameter"] as? Float {
                    let previous = strongSelf.currentValue
                    if !previous.isEqual(to: volume) {
                        strongSelf.currentValue = volume
                        if strongSelf.ignoreAdjustmentOnce {
                            strongSelf.ignoreAdjustmentOnce = false
                        } else {
                            valueChanged()
                        }
                    }
                }
            }
        })
        
        view.addSubview(self.control)
    }
    
    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        self.control.removeFromSuperview()
    }
}
