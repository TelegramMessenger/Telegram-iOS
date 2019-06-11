#import "TGAttachmentCameraCell.h"

NSString *const TGAttachmentCameraCellIdentifier = @"AttachmentCameraCell";

@implementation TGAttachmentCameraCell

- (void)attachCameraViewIfNeeded:(TGAttachmentCameraView *)cameraView
{
    if (_cameraView == cameraView)
        return;
    
    _cameraView = cameraView;
    _cameraView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _cameraView.frame = self.bounds;
    [self addSubview:cameraView];
}

@end
