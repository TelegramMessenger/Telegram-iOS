#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

@protocol TGStickerPackReference <NSObject, NSCopying, PSCoding, NSCoding>

@end

@interface TGStickerPackBuiltinReference : NSObject <TGStickerPackReference>

@end

@interface TGStickerPackIdReference : NSObject <TGStickerPackReference>

@property (nonatomic, readonly) int64_t packId;
@property (nonatomic, readonly) int64_t packAccessHash;
@property (nonatomic, strong, readonly) NSString *shortName;

- (instancetype)initWithPackId:(int64_t)packId packAccessHash:(int64_t)packAccessHash shortName:(NSString *)shortName;

@end

@interface TGStickerPackShortnameReference : NSObject <TGStickerPackReference>

@property (nonatomic, strong, readonly) NSString *shortName;

- (instancetype)initWithShortName:(NSString *)shortName;

@end
