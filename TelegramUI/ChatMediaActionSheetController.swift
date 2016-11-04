import Foundation
import Display
import AsyncDisplayKit
import UIKit
import SwiftSignalKit
import Photos

final class ChatMediaActionSheetController: ActionSheetController {
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    var photo: (PHAsset) -> Void = { _ in }
    var files: () -> Void = { }
    var location: () -> Void = { }
    var contacts: () -> Void = { }
    
    override init() {
        super.init()
        
        self._ready.set(.single(true))
        
        self.setItemGroups([
            ActionSheetItemGroup(items: [
                ChatMediaActionSheetRollItem(assetSelected: { [weak self] asset in
                    if let strongSelf = self {
                        self?.dismissAnimated()
                        strongSelf.photo(asset)
                    }
                }),
                ActionSheetButtonItem(title: "File", action: { [weak self] in
                    if let strongSelf = self {
                        self?.dismissAnimated()
                        strongSelf.files()
                    }
                }),
                ActionSheetButtonItem(title: "Location", action: { [weak self] in
                    self?.dismissAnimated()
                    if let location = self?.location {
                        location()
                    }
                }),
                ActionSheetButtonItem(title: "Contact", action: { [weak self] in
                    self?.dismissAnimated()
                    if let contacts = self?.contacts {
                        contacts()
                    }
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Cancel", action: { [weak self] in
                    self?.dismissAnimated()
                }),
            ])
        ])
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
