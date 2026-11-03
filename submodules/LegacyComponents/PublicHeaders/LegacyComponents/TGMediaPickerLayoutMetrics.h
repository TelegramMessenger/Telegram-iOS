#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGMediaPickerLayoutMetrics : NSObject

@property (nonatomic, readonly) CGFloat widescreenWidth;
@property (nonatomic, readonly) CGSize normalItemSize;
@property (nonatomic, readonly) CGSize wideItemSize;
@property (nonatomic, readonly) UIEdgeInsets normalEdgeInsets;
@property (nonatomic, readonly) UIEdgeInsets wideEdgeInsets;
@property (nonatomic, readonly) CGFloat normalLineSpacing;
@property (nonatomic, readonly) CGFloat wideLineSpacing;

- (CGSize)imageSize;

- (CGSize)itemSizeForCollectionViewWidth:(CGFloat)collectionViewWidth;

+ (TGMediaPickerLayoutMetrics *)defaultLayoutMetrics;
+ (TGMediaPickerLayoutMetrics *)panoramaLayoutMetrics;

@end
