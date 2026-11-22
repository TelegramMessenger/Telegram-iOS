#ifndef FreedomUIKit_h
#define FreedomUIKit_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    
void freedomUIKitInit();

bool freedomUIKitTest3();
bool freedomUIKitTest3_1();
void freedomUIKitTest4(dispatch_block_t);
void freedomUIKitTest4_1();
    
@interface FFNotificationCenter : NSNotificationCenter

+ (void)setShouldRotateBlock:(bool (^)())block;

@end
    
#ifdef __cplusplus
}
#endif

#endif
