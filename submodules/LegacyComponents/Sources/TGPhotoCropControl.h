#import <UIKit/UIKit.h>

@interface TGPhotoCropControl : UIControl

@property (nonatomic, copy) bool(^shouldBeginResizing)(TGPhotoCropControl *sender);
@property (nonatomic, copy) void(^didBeginResizing)(TGPhotoCropControl *sender);
@property (nonatomic, copy) void(^didResize)(TGPhotoCropControl *sender, CGPoint translation);
@property (nonatomic, copy) void(^didEndResizing)(TGPhotoCropControl *sender);

@end
