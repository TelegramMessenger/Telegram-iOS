#import <UIKit/UIKit.h>

#import "GPUImageContext.h"

@interface PGPhotoEditorView : UIView <GPUImageInput>

@property (nonatomic, assign) bool enabled;

@end
