#import <UIKit/UIKit.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@protocol TGLegacyCameraControllerDelegate <NSObject>

@optional

- (void)legacyCameraControllerCapturedVideoWithTempFilePath:(NSString *)tempVideoFilePath fileSize:(int32_t)fileSize previewImage:(UIImage *)previewImage duration:(NSTimeInterval)duration dimensions:(CGSize)dimenstions assetUrl:(NSString *)assetUrl;
- (void)legacyCameraControllerCompletedWithExistingMedia:(id)media;
- (void)legacyCameraControllerCompletedWithNoResult;
- (void)legacyCameraControllerCompletedWithDocument:(NSURL *)fileUrl fileName:(NSString *)fileName mimeType:(NSString *)mimeType;

@end

@interface TGLegacyCameraController : UIImagePickerController

@property (nonatomic, copy) void (^finishedWithImage)(UIImage *);

@property (nonatomic, weak) id<TGLegacyCameraControllerDelegate> completionDelegate;
@property (nonatomic) bool storeCapturedAssets;
@property (nonatomic) bool isInDocumentMode;
@property (nonatomic) bool avatarMode;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context;

@end
