#ifndef Lottie_h
#define Lottie_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GiftPatternRect : NSObject

@property (nonatomic) CGPoint center;
@property (nonatomic) CGFloat side;
@property (nonatomic) CGFloat rotation;
@property (nonatomic) CGFloat scale;

@end

@interface GiftPatternData : NSObject

@property (nonatomic) CGSize size;
@property (nonatomic, strong) NSArray<GiftPatternRect *> * _Nonnull rects;

@end

NSData * _Nullable prepareSvgImage(NSData * _Nonnull data, bool pattern);

GiftPatternData * _Nullable getGiftPatternData(NSData * _Nonnull data);

UIImage * _Nullable renderPreparedImage(NSData * _Nonnull data, CGSize size, UIColor * _Nonnull backgroundColor, CGFloat scale, bool fit);
UIImage * _Nullable renderPreparedImageWithSymbol(NSData * _Nonnull data, CGSize size, UIColor * _Nonnull backgroundColor, CGFloat scale, bool fit, UIImage * _Nullable symbolImage, int32_t modelRectIndex);

UIImage * _Nullable drawSvgImage(NSData * _Nonnull data, CGSize size, UIColor * _Nullable backgroundColor, UIColor * _Nullable foregroundColor, CGFloat scale, bool opaque);

#endif /* Lottie_h */
