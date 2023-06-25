import Foundation
import UIKit
import SwiftSignalKit
import MediaPlayer

import LegacyComponents

public class VolumeButtonsListener: NSObject {
    private let handler: PGCameraVolumeButtonHandler
    
    private var disposable: Disposable?
    
    public init(
        shouldBeActive: Signal<Bool, NoError>,
        upPressed: @escaping () -> Void,
        upReleased: @escaping () -> Void = {},
        downPressed: @escaping () -> Void,
        downReleased: @escaping () -> Void = {}
    ) {
        self.handler = PGCameraVolumeButtonHandler(upButtonPressedBlock: {
            upPressed()
        }, upButtonReleasedBlock: {
            upReleased()
        }, downButtonPressedBlock: {
            downPressed()
        }, downButtonReleasedBlock: {
            downReleased()
        })
        
        super.init()
                
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
