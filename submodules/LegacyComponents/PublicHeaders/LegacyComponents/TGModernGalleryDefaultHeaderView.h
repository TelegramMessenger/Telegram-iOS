#import <UIKit/UIKit.h>

#import <LegacyComponents/TGModernGalleryItem.h>

@protocol TGModernGalleryDefaultHeaderView <NSObject>

@required

- (void)setItem:(id<TGModernGalleryItem>)item;

@end
