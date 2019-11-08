import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramPresentationData
import LegacyUI

private final class LegacyImagePickerController: LegacyController, TGLegacyCameraControllerDelegate, TGImagePickerControllerDelegate {
    private let completion: (UIImage?) -> Void
    
    init(presentation: LegacyControllerPresentation, theme: PresentationTheme?, completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        
        super.init(presentation: presentation, theme: theme)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    func legacyCameraControllerCompletedWithNoResult() {
        self.completion(nil)
    }
    
    func imagePickerController(_ imagePicker: TGImagePickerController!, didFinishPickingWithAssets assets: [Any]!) {
        if let image = assets.first as? UIImage {
            self.completion(image)
        } else {
            self.completion(nil)
        }
    }
}

func legacyImagePicker(theme: PresentationTheme, completion: @escaping (UIImage?) -> Void) -> ViewController {
    let legacyController = LegacyImagePickerController(presentation: .modal(animateIn: true), theme: theme, completion: { image in
        completion(image)
    })
    
    let imagePickerController = TGLegacyCameraController(context: legacyController.context)!
    imagePickerController.sourceType = UIImagePickerController.SourceType.photoLibrary
    imagePickerController.completionDelegate = legacyController
    
    legacyController.bind(controller: imagePickerController)
    
    return legacyController
}
