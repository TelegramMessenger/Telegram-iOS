#import "TGRTLScreenEdgePanGestureRecognizer.h"

#import "Freedom.h"

@implementation TGRTLScreenEdgePanGestureRecognizer

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    if (touch != nil) {
        static NSArray<Class> *disabledClassList = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableArray *array = [[NSMutableArray alloc] init];
            for (NSString *name in @[@"TGModernConversationInputMicButton", @"TGModernConversationInputAttachButton"]) {
                Class className = NSClassFromString(name);
                if (className != nil) {
                    [array addObject:className];
                }
            }
            disabledClassList = array;
        });
        
        CGPoint location = [touch locationInView:self.view];
        UIView *targetView = [self.view hitTest:location withEvent:event];
        for (Class className in disabledClassList) {
            if ([targetView isKindOfClass:className]) {
                self.state = UIGestureRecognizerStateFailed;
                return;
            }
        }
    }
    
    [super touchesBegan:touches withEvent:event];
}

- (void)setState:(UIGestureRecognizerState)state {
    [super setState:state];
}

@end

@implementation TGRTLScreenEdgePanGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(id)arg1 shouldReceiveTouch:(id)arg2 {
    static BOOL (*nativeImpl)(id, SEL, id, id) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nativeImpl = (BOOL (*)(id, SEL, id, id))freedomNativeImpl([[self class] superclass], _cmd);
    });
    
    if (nativeImpl != NULL) {
        return nativeImpl(self, _cmd, arg1, arg2);
    }
    
    return true;
}

@end
