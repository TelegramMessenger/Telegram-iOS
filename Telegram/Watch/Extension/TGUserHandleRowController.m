#import "TGUserHandleRowController.h"
#import "TGUserHandle.h"

NSString *const TGUserHandleRowIdentifier = @"TGUserHandleRow";

@implementation TGUserHandleRowController

- (void)updateWithUserHandle:(TGUserHandle *)userHandle
{
    bool useRegularFont = (userHandle.handleType == TGUserHandleTypeDescription);
    
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    attributes[NSFontAttributeName] = useRegularFont ? [UIFont systemFontOfSize:16.0f weight:UIFontWeightRegular] : [UIFont systemFontOfSize:16.0f weight:UIFontWeightMedium];
    attributes[NSForegroundColorAttributeName] = [UIColor whiteColor];
    
    if (useRegularFont)
    {
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.hyphenationFactor = 1.0f;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;
    }
    
    NSString *handle = userHandle.handle;
    if (handle == nil)
        handle = @"";
    
    self.handleLabel.attributedText = [[NSAttributedString alloc] initWithString:handle attributes:attributes];
    self.typeLabel.text = userHandle.type;
}

+ (NSString *)identifier
{
    return TGUserHandleRowIdentifier;
}

@end

NSString *const TGUserHandleActiveRowIdentifier = @"TGUserHandleActiveRow";

@implementation TGUserHandleActiveRowController

+ (NSString *)identifier
{
    return TGUserHandleActiveRowIdentifier;
}

@end
