#import "TGInterfaceController.h"

@interface TGProfilePhotoControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, readonly) int64_t identifier;
@property (nonatomic, readonly) NSString *imageUrl;

- (instancetype)initWithIdentifier:(int64_t)identifier imageUrl:(NSString *)imageUrl;

@end

@interface TGProfilePhotoController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *imageGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@end
