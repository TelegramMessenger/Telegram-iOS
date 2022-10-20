#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGPaintBrush : NSObject
{
    CGImageRef _previewStampRef;
}

@property (nonatomic, readonly) CGFloat spacing;
@property (nonatomic, readonly) CGFloat alpha;
@property (nonatomic, readonly) CGFloat angle;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGFloat dynamic;
@property (nonatomic, readonly) bool lightSaber;
@property (nonatomic, readonly) bool arrow;

@property (nonatomic, readonly) CGImageRef stampRef;
@property (nonatomic, readonly) CGImageRef previewStampRef;

@property (nonatomic, strong) UIImage *previewImage;

@end

extern const CGSize TGPaintBrushTextureSize;
extern const CGSize TGPaintBrushPreviewTextureSize;
