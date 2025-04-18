#import "TGMessageViewWebPageRowController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "WKInterfaceGroup+Signals.h"
#import "TGBridgeMediaSignals.h"

#import "TGMessageViewModel.h"

NSString *const TGMessageViewWebPageRowIdentifier = @"TGMessageViewWebPageRow";

@interface TGMessageViewWebPageRowController ()
{
    int64_t _photoId;
}
@end

@implementation TGMessageViewWebPageRowController

- (void)updateWithAttachment:(TGBridgeWebPageMediaAttachment *)attachment message:(TGBridgeMessage *)message
{
    if (attachment.siteName.length > 0)
        self.siteNameLabel.text = attachment.siteName;
    else
        self.siteNameLabel.hidden = true;
    
    bool inTextImage = !([attachment.pageType isEqualToString:@"photo"] || [attachment.pageType isEqualToString:@"video"]);
    if (attachment.pageDescription.length == 0)
        inTextImage = false;

    NSString *title = attachment.title;
    if (title.length == 0)
        title = attachment.author;
    
    if (title.length > 0)
        self.titleLabel.text = title;
    else
        self.titleLabel.hidden = true;
    
    if (attachment.pageDescription.length > 0)
        self.textLabel.text = attachment.pageDescription;
    else
        self.textLabel.hidden = true;
    
    if (attachment.photo != nil)
    {
        if (inTextImage)
        {
            self.imageGroup.hidden = true;
            
            [self.titleImageGroup setBackgroundImageSignal:[TGBridgeMediaSignals thumbnailWithPeerId:message.cid messageId:message.identifier size:CGSizeMake(26, 26) notification:false] isVisible:self.isVisible];
        }
        else
        {
            self.titleImageGroup.hidden = true;
            self.imageGroup.hidden = false;
            
            CGSize imageSize = CGSizeZero;
            
            [TGMessageViewModel updateMediaGroup:self.imageGroup activityIndicator:self.activityIndicator attachment:attachment.photo message:message notification:false currentPhoto:&_photoId standalone:true margin:0 imageSize:&imageSize isVisible:self.isVisible completion:nil];
            
            self.imageGroup.width = imageSize.width;
            self.imageGroup.height = imageSize.height;
        }
    }
    else
    {
        self.titleImageGroup.hidden = true;
        self.imageGroup.hidden = true;
    }
    
    if (attachment.duration != nil)
    {
        self.durationGroup.hidden = false;
        
        NSInteger duration = [attachment.duration doubleValue];
        NSInteger durationMinutes = floor(duration / 60.0);
        NSInteger durationSeconds = duration % 60;
        self.durationLabel.text = [NSString stringWithFormat:@"%ld:%02ld", (long)durationMinutes, (long)durationSeconds];
    }
}

+ (NSString *)identifier
{
    return TGMessageViewWebPageRowIdentifier;
}

@end
