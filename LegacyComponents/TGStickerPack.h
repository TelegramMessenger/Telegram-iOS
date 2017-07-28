#import <Foundation/Foundation.h>

#import <LegacyComponents/LegacyComponents.h>

@interface TGStickerPack : NSObject <NSCoding, PSCoding>

@property (nonatomic, strong, readonly) id<TGStickerPackReference> packReference;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSArray *stickerAssociations;
@property (nonatomic, strong, readonly) NSArray *documents;
@property (nonatomic, readonly) int32_t packHash;
@property (nonatomic, readonly) bool hidden;
@property (nonatomic, readonly) bool isMask;

- (instancetype)initWithPackReference:(id<TGStickerPackReference>)packReference title:(NSString *)title stickerAssociations:(NSArray *)stickerAssociations documents:(NSArray *)documents packHash:(int32_t)packHash hidden:(bool)hidden isMask:(bool)isMask;

@end
