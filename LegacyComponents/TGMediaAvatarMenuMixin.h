#import <Foundation/Foundation.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;
@class TGMenuSheetController;
@class TGMediaAssetsController;

typedef void (^TGMediaAvatarPresentImpl)(id<LegacyComponentsContext>, void (^)(UIViewController *));

@interface TGMediaAvatarMenuMixin : NSObject

@property (nonatomic, copy) void (^didFinishWithImage)(UIImage *image);
@property (nonatomic, copy) void (^didFinishWithDelete)(void);
@property (nonatomic, copy) void (^didFinishWithView)(void);
@property (nonatomic, copy) void (^didDismiss)(void);
@property (nonatomic, copy) void (^requestSearchController)(TGMediaAssetsController *);
@property (nonatomic, copy) CGRect (^sourceRect)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasDeleteButton:(bool)hasDeleteButton saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasDeleteButton:(bool)hasDeleteButton personalPhoto:(bool)personalPhoto saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasSearchButton:(bool)hasSearchButton hasDeleteButton:(bool)hasDeleteButton hasViewButton:(bool)hasViewButton personalPhoto:(bool)personalPhoto saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia signup:(bool)signup;
- (TGMenuSheetController *)present;

@end
