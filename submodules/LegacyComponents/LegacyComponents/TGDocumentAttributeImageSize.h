#import <LegacyComponents/PSCoding.h>

#import <UIKit/UIKit.h>

@interface TGDocumentAttributeImageSize : NSObject <PSCoding, NSCoding>

@property (nonatomic, readonly) CGSize size;

- (instancetype)initWithSize:(CGSize)size;

@end
