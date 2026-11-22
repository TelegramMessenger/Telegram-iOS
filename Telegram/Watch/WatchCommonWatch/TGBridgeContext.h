#import <Foundation/Foundation.h>

@interface TGBridgeContext : NSObject

@property (nonatomic, readonly) bool authorized;
@property (nonatomic, readonly) int64_t userId;
@property (nonatomic, readonly) bool micAccessAllowed;
@property (nonatomic, readonly) NSDictionary *preheatData;
@property (nonatomic, readonly) NSInteger preheatVersion;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionary;

- (TGBridgeContext *)updatedWithAuthorized:(bool)authorized peerId:(int32_t)peerId;
- (TGBridgeContext *)updatedWithPreheatData:(NSDictionary *)data;
- (TGBridgeContext *)updatedWithMicAccessAllowed:(bool)allowed;

@end
