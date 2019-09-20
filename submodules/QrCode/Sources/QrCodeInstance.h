#ifndef QrCodeInstance_h
#define QrCodeInstance_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface QrCodeInstance : NSObject

@property (nonatomic, readonly) NSString *string;
@property (nonatomic, readonly) int32_t size;

- (instancetype _Nullable)initWithStirng:(NSString * _Nonnull)string;

- (BOOL)getModuleAtX:(int32_t)x y:(int32_t)y;

@end

#endif /* QrCodeInstance_h */
