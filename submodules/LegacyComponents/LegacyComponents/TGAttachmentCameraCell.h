#import "TGAttachmentMenuCell.h"
#import "TGAttachmentCameraView.h"

@interface TGAttachmentCameraCell : TGAttachmentMenuCell

@property (nonatomic, readonly) TGAttachmentCameraView *cameraView;

- (void)attachCameraViewIfNeeded:(TGAttachmentCameraView *)cameraView;

@end

extern NSString *const TGAttachmentCameraCellIdentifier;
