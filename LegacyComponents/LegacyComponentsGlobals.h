#import <Foundation/Foundation.h>

@class TGLocalization;

@protocol LegacyComponentsGlobalsProvider <NSObject>

- (TGLocalization *)effectiveLocalization;
- (void)log:(NSString *)format :(va_list)args;

@end

@interface LegacyComponentsGlobals : NSObject

+ (void)setProvider:(id<LegacyComponentsGlobalsProvider>)provider;
+ (id<LegacyComponentsGlobalsProvider>)provider;

@end

