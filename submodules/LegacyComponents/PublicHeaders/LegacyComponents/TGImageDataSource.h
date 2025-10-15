#import <LegacyComponents/TGDataResource.h>

@interface TGImageDataSource : NSObject

+ (void)registerDataSource:(TGImageDataSource *)dataSource;
+ (void)enumerateDataSources:(bool (^)(TGImageDataSource *dataSource))handler;

+ (void)enqueueImageProcessingBlock:(void (^)())imageProcessingBlock;

- (bool)canHandleUri:(NSString *)uri;
- (bool)canHandleAttributeUri:(NSString *)uri;
- (TGDataResource *)loadDataSyncWithUri:(NSString *)uri canWait:(bool)canWait acceptPartialData:(bool)acceptPartialData asyncTaskId:(__autoreleasing id *)asyncTaskId progress:(void (^)(float))progress partialCompletion:(void (^)(TGDataResource *))partialCompletion completion:(void (^)(TGDataResource *))completion;
- (id)loadDataAsyncWithUri:(NSString *)uri progress:(void (^)(float progress))progress partialCompletion:(void (^)(TGDataResource *resource))partialCompletion completion:(void (^)(TGDataResource *resource))completion;
- (id)loadAttributeSyncForUri:(NSString *)uri attribute:(NSString *)attribute;
- (void)cancelTaskById:(id)taskId;

@end
