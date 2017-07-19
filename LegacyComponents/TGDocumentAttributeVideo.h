#import <UIKit/UIKit.h>

#import <LegacyComponents/PSCoding.h>

@interface TGDocumentAttributeVideo : NSObject <PSCoding, NSCoding>

@property (nonatomic, readonly) bool isRoundMessage;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) int32_t duration;

- (instancetype)initWithRoundMessage:(bool)isRoundMessage size:(CGSize)size duration:(int32_t)duration;

@end
