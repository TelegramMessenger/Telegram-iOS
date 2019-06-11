#ifndef IpcNotifier_h
#define IpcNotifier_h

#import <Foundation/Foundation.h>

@interface RLMNotifier : NSObject

- (instancetype _Nonnull)initWithBasePath:(NSString * _Nonnull)basePath notify:(void (^ _Nonnull)())notify;
- (void)listen;
- (void)notifyOtherRealms;

@end

#endif
