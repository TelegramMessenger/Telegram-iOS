import Foundation
import UIKit
import SwiftSignalKit
import MediaPlayer

import LegacyComponents

class VolumeButtonsListener: NSObject {
    private let handler: PGCameraVolumeButtonHandler
    
    private var disposable: Disposable?
    
    init(shouldBeActive: Signal<Bool, NoError>, valueChanged: @escaping () -> Void) {
        var impl: (() -> Void)?
        
        self.handler = PGCameraVolumeButtonHandler(upButtonPressedBlock: {
            impl?()
        }, upButtonReleasedBlock: {}, downButtonPressedBlock: {
            impl?()
        }, downButtonReleasedBlock: {})
        
        super.init()
        
        impl = {
            valueChanged()
        }
        
        self.disposable = (shouldBeActive
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.handler.enabled = value
        })
    }
    
    deinit {
        self.handler.enabled = false
        self.disposable?.dispose()
    }
}
