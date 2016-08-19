#ifndef IpcNotifier_h
#define IpcNotifier_h

#import <Foundation/Foundation.h>

@interface RLMNotifier : NSObject

- (instancetype)initWithBasePath:(NSString *)basePath notify:(void (^)())notify;
- (void)listen;
- (void)notifyOtherRealms;

@end

#endif
