#import "TGNeoViewModel.h"
#import <UIKit/UIKit.h>

@class TGBridgeUser;

@interface TGNeoAttachmentViewModel : TGNeoViewModel

@property (nonatomic, readonly) bool inhibitsInitials;
@property (nonatomic, readonly) bool hasCaption;

- (instancetype)initWithAttachments:(NSArray *)attachments author:(TGBridgeUser *)author forChannel:(bool)forChannel users:(NSDictionary *)users font:(UIFont *)font subTitleColor:(UIColor *)subTitleColor normalColor:(UIColor *)normalColor compact:(bool)compact caption:(NSString *)caption;

@end
