#import <Foundation/Foundation.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;
@class TGMenuSheetController;
@class TGMediaAssetsController;

@interface TGMediaAvatarMenuMixin : NSObject

@property (nonatomic, copy) void (^didFinishWithImage)(UIImage *image);
@property (nonatomic, copy) void (^didFinishWithDelete)(void);
@property (nonatomic, copy) void (^didFinishWithView)(void);
@property (nonatomic, copy) void (^didDismiss)(void);
@property (nonatomic, copy) TGViewController *(^requestSearchController)(TGMediaAssetsController *);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasDeleteButton:(bool)hasDeleteButton saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasDeleteButton:(bool)hasDeleteButton personalPhoto:(bool)personalPhoto saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasDeleteButton:(bool)hasDeleteButton hasViewButton:(bool)hasViewButton personalPhoto:(bool)personalPhoto saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia;
- (TGMenuSheetController *)present;

@end
