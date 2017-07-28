#import <Foundation/Foundation.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;

@interface TGMediaAvatarMenuMixin : NSObject

@property (nonatomic, copy) void (^didFinishWithImage)(UIImage *image);
@property (nonatomic, copy) void (^didFinishWithDelete)(void);
@property (nonatomic, copy) void (^didDismiss)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasDeleteButton:(bool)hasDeleteButton saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasDeleteButton:(bool)hasDeleteButton personalPhoto:(bool)personalPhoto saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia;
- (void)present;

@end
