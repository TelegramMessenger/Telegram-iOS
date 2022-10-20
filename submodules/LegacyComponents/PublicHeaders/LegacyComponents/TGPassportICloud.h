#import <Foundation/Foundation.h>

@class SSignal;

@interface TGPassportICloud : NSObject

+ (SSignal *)fetchICloudFileWith:(NSURL *)url;

@end
