#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TGPaintBrush;

@interface TGPaintState : NSObject

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign, getter=isEraser) bool eraser;
@property (nonatomic, assign) CGFloat weight;
@property (nonatomic, strong) TGPaintBrush *brush;

@end
