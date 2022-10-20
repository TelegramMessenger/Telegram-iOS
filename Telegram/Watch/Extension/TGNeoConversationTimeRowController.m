#import "TGNeoConversationTimeRowController.h"
#import "TGChatTimestamp.h"

#import "TGExtensionDelegate.h"

NSString *const TGNeoConversationTimeRowIdentifier = @"TGNeoConversationTimeRow";

@implementation TGNeoConversationTimeRowController

- (void)updateWithTimestamp:(TGChatTimestamp *)timestamp
{
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:timestamp.string attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:[TGNeoConversationTimeRowController textFontSize]], NSForegroundColorAttributeName: [UIColor whiteColor] }];
    self.label.attributedText = attributedText;
}

+ (CGFloat)textFontSize
{
    TGContentSizeCategory category = [TGExtensionDelegate instance].contentSizeCategory;
    
    switch (category)
    {
        case TGContentSizeCategoryXS:
            return 10.0f;
            
        case TGContentSizeCategoryS:
            return 11.0f;
            
        case TGContentSizeCategoryL:
            return 12.0f;
            
        case TGContentSizeCategoryXL:
            return 13.0f;
            
        case TGContentSizeCategoryXXL:
            return 14.0f;
            
        case TGContentSizeCategoryXXXL:
            return 15.0f;
            
        default:
            break;
    }
    
    return 16.0f;
}

+ (NSString *)identifier
{
    return TGNeoConversationTimeRowIdentifier;
}

@end
