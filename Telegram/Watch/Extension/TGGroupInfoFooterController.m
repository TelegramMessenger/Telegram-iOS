#import "TGGroupInfoFooterController.h"

NSString *const TGGroupInfoFooterIdentifier = @"TGGroupInfoFooter";

@implementation TGGroupInfoFooterController

- (IBAction)buttonPressedAction
{
    if (self.buttonPressed != nil)
        self.buttonPressed();
}

#pragma mark -

+ (NSString *)identifier
{
    return TGGroupInfoFooterIdentifier;
}

@end
