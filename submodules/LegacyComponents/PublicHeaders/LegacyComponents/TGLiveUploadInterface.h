#import <Foundation/Foundation.h>

@protocol TGLiveUploadInterface <NSObject>

- (void)setupWithFileURL:(NSURL *)fileURL;
- (id)fileUpdated:(bool)completed;

@end
