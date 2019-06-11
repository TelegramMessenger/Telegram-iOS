#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

@interface TGStickerAssociation : NSObject <NSCoding, PSCoding>

@property (nonatomic, strong, readonly) NSString *key;
@property (nonatomic, strong, readonly) NSArray *documentIds;

- (instancetype)initWithKey:(NSString *)key documentIds:(NSArray *)documentIds;

@end
