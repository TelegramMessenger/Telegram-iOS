#import <UIKit/UIKit.h>

@interface TGPhotoPaintActionsView : UIView

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (nonatomic, copy) void (^undoPressed)(void);
@property (nonatomic, copy) void (^redoPressed)(void);
@property (nonatomic, copy) void (^clearPressed)(UIView *);

- (void)setUndoEnabled:(bool)enabled;
- (void)setRedoEnabled:(bool)enabled;
- (void)setClearEnabled:(bool)enabled;

@end
