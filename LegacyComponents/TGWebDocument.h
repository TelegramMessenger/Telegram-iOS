#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

#import <LegacyComponents/TGDocumentMediaAttachment.h>

@interface TGWebDocumentReference : NSObject <PSCoding>

@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, readonly) int64_t accessHash;
@property (nonatomic, readonly) int32_t size;
@property (nonatomic, readonly) int32_t datacenterId;

- (instancetype)initWithUrl:(NSString *)url accessHash:(int64_t)accessHash size:(int32_t)size datacenterId:(int32_t)datacenterId;

- (instancetype)initWithString:(NSString *)string;
- (NSString *)toString;

@end

@interface TGWebDocument : NSObject <NSCoding>

@property (nonatomic, readonly) bool noProxy;
@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, readonly) int64_t accessHash;
@property (nonatomic, readonly) int32_t size;
@property (nonatomic, strong, readonly) NSString *mimeType;
@property (nonatomic, strong, readonly) NSArray *attributes;
@property (nonatomic, readonly) int32_t datacenterId;

@property (nonatomic, strong, readonly) TGWebDocumentReference *reference;

- (instancetype)initWithNoProxy:(bool)noProxy url:(NSString *)url accessHash:(int64_t)accessHash size:(int32_t)size mimeType:(NSString *)mimeType attributes:(NSArray *)attributes datacenterId:(int32_t)datacenterId;

@end
