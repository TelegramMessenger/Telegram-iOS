#import <Foundation/Foundation.h>

@protocol TGModernGalleryItem;

@protocol TGModernGalleryDefaultFooterAccessoryView <NSObject>

@required

- (void)setItem:(id<TGModernGalleryItem>)item;

@end
