#import <LegacyComponents/ActionStage.h>

#import <AssetsLibrary/AssetsLibrary.h>

#ifdef __cplusplus
extern "C" {
#endif

void dispatchOnAssetsProcessingQueue(dispatch_block_t block);
void sharedAssetsLibraryRetain();
void sharedAssetsLibraryRelease();
    
#ifdef __cplusplus
}
#endif

@protocol TGImagePickerControllerDelegate;

@interface TGImagePickerController : NSObject

+ (id)sharedAssetsLibrary;
+ (id)preloadLibrary;
+ (void)loadAssetWithUrl:(NSURL *)url completion:(void (^)(ALAsset *asset))completion;
+ (void)storeImageAsset:(NSData *)data;

@end

@protocol TGImagePickerControllerDelegate <NSObject>

- (void)imagePickerController:(TGImagePickerController *)imagePicker didFinishPickingWithAssets:(NSArray *)assets;

@end
