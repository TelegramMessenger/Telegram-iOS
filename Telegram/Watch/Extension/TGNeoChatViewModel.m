#import "TGNeoChatViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGNeoLabelViewModel.h"
#import "TGNeoImageViewModel.h"
#import "TGNeoAttachmentViewModel.h"

#import "TGExtensionDelegate.h"
#import "TGStringUtils.h"
#import "TGDateUtils.h"

@interface TGNeoChatViewModel ()
{
    TGNeoLabelViewModel *_nameModel;
    TGNeoLabelViewModel *_authorNameModel;
    TGNeoImageViewModel *_verifiedModel;
    TGNeoLabelViewModel *_authorInitialsModel;
    TGNeoLabelViewModel *_textModel;
    TGNeoAttachmentViewModel *_attachmentModel;
    TGNeoLabelViewModel *_timeModel;
}
@end

@implementation TGNeoChatViewModel

- (instancetype)initWithChat:(TGBridgeChat *)chat users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super init];
    if (self != nil)
    {
        TGBridgeUser *author = nil;
        NSString *name = nil;
        
        if (chat.isGroup || chat.isChannelGroup)
        {
            author = users[@(chat.fromUid)];
            name = chat.groupTitle;
        }
        else if (chat.isChannel)
        {
            name = chat.groupTitle;
        }
        else if (chat.identifier == context.userId)
        {
            name = TGLocalized(@"DialogList.SavedMessages");
        }
        else
        {
            author = users[@(chat.identifier)];
            name = [author displayName];
        }
        
        _nameModel = [[TGNeoLabelViewModel alloc] initWithText:name font:[UIFont systemFontOfSize:[TGNeoChatViewModel titleFontSize] weight:UIFontWeightMedium] color:[UIColor whiteColor] attributes:nil];
        _nameModel.multiline = false;
        [self addSubmodel:_nameModel];
        
        if (chat.verified || author.verified)
        {
            _verifiedModel = [[TGNeoImageViewModel alloc] initWithImage:[UIImage imageNamed:@"VerifiedList"]];
            [self addSubmodel:_verifiedModel];
        }
        
        _attachmentModel = [[TGNeoAttachmentViewModel alloc] initWithAttachments:chat.media author:author forChannel:(chat.isChannel && !chat.isChannelGroup) users:users font:[UIFont systemFontOfSize:[TGNeoChatViewModel textFontSize]] subTitleColor:[UIColor hexColor:0x8f8f8f] normalColor:[UIColor whiteColor] compact:false caption:chat.text];
        if (_attachmentModel != nil)
            [self addSubmodel:_attachmentModel];
        
        if ((chat.isGroup || chat.isChannelGroup) && !_attachmentModel.inhibitsInitials)
        {
            NSString *initials = (chat.fromUid == context.userId) ? TGLocalized(@"DialogList.You") : [TGStringUtils initialsForFirstName:author.firstName lastName:author.lastName single:false];
            
            if (initials.length > 0)
            {
                _authorInitialsModel = [[TGNeoLabelViewModel alloc] initWithText:[NSString stringWithFormat:@"%@:", initials] font:[UIFont systemFontOfSize:[TGNeoChatViewModel textFontSize] weight:UIFontWeightMedium] color:[UIColor whiteColor] attributes:nil];
                _authorInitialsModel.multiline = false;
                [self addSubmodel:_authorInitialsModel];
            }
        }
        
        if (chat.text.length > 0 && !_attachmentModel.hasCaption)
        {
            _textModel = [[TGNeoLabelViewModel alloc] initWithText:chat.text font:[UIFont systemFontOfSize:[TGNeoChatViewModel textFontSize]] color:[UIColor hexColor:0x8f8f8f] attributes:nil];
            _textModel.multiline = false;
            [self addSubmodel:_textModel];
        }
        
        NSString *time = @"";
        if (chat.date > 0)
            time = [TGDateUtils stringForMessageListDate:chat.date];
        
        _timeModel = [[TGNeoLabelViewModel alloc] initWithText:time font:[UIFont systemFontOfSize:[TGNeoChatViewModel timeFontSize]] color:[UIColor hexColor:0x8f8f8f] attributes:nil];
        _timeModel.multiline = false;
        [self addSubmodel:_timeModel];
    }
    return self;
}

- (CGSize)layoutWithContainerSize:(CGSize)containerSize
{
    CGSize nameSize = [_nameModel contentSizeWithContainerSize:CGSizeMake(containerSize.width - 31 - 7, FLT_MAX)];

    if (_verifiedModel != nil)
    {
        CGFloat margin = 4;
        _verifiedModel.frame = CGRectMake(MIN(31.5f + nameSize.width + margin, containerSize.width - 20), 6, 12, 12);
        nameSize.width = MIN(nameSize.width, _verifiedModel.frame.origin.x - 31.5f - margin);

        _nameModel.frame = CGRectMake(31.5f, 1.5f, nameSize.width, nameSize.height);
    }
    else
    {
        _nameModel.frame = CGRectMake(31.5f, 1.5f, containerSize.width - 31 - 7, nameSize.height);
    }
    
    CGFloat textX = 0;
    CGFloat textY = CGRectGetMaxY(_nameModel.frame) - 2.5f;
    if (_authorInitialsModel != nil)
    {
        CGFloat width = [_authorInitialsModel contentSizeWithContainerSize:CGSizeMake(40, 20)].width + 4;
        _authorInitialsModel.frame = CGRectMake(31.5f, textY, width, 20);
        textX += width;
    }
    
    TGNeoViewModel *contentViewModel = (_attachmentModel != nil) ? _attachmentModel : _textModel;
    CGSize textSize = [contentViewModel contentSizeWithContainerSize:CGSizeMake(containerSize.width - 31 - 7, FLT_MAX)];
    contentViewModel.frame = CGRectMake(31.5f + textX, textY, containerSize.width - 31 - 7 - textX, textSize.height);
    
    CGSize timeSize = [_timeModel contentSizeWithContainerSize:CGSizeMake(containerSize.width - 31 - 7, FLT_MAX)];
    _timeModel.frame = CGRectMake(31.5f, CGRectGetMaxY(contentViewModel.frame) - 1, containerSize.width - 31 - 36, timeSize.height);
    
    self.contentSize = CGSizeMake(containerSize.width, CGRectGetMaxY(_timeModel.frame) + 3);
    return self.contentSize;
}

+ (CGFloat)titleFontSize
{
    TGContentSizeCategory category = [TGExtensionDelegate instance].contentSizeCategory;
    
    switch (category)
    {
        case TGContentSizeCategoryXS:
            return 14.0f;
            
        case TGContentSizeCategoryS:
            return 15.0f;
            
        case TGContentSizeCategoryL:
            return 16.0f;
            
        case TGContentSizeCategoryXL:
            return 17.0f;
            
        case TGContentSizeCategoryXXL:
            return 18.0f;
            
        case TGContentSizeCategoryXXXL:
            return 19.0f;
            
        default:
            break;
    }
    
    return 16.0f;
}

+ (CGFloat)textFontSize
{
    TGContentSizeCategory category = [TGExtensionDelegate instance].contentSizeCategory;
    
    switch (category)
    {
        case TGContentSizeCategoryXS:
            return 14.0f;
            
        case TGContentSizeCategoryS:
            return 15.0f;
            
        case TGContentSizeCategoryL:
            return 16.0f;
            
        case TGContentSizeCategoryXL:
            return 17.0f;
            
        case TGContentSizeCategoryXXL:
            return 18.0f;
            
        case TGContentSizeCategoryXXXL:
            return 19.0f;
            
        default:
            break;
    }
    
    return 16.0f;
}

+ (CGFloat)timeFontSize
{
    TGContentSizeCategory category = [TGExtensionDelegate instance].contentSizeCategory;
    
    switch (category)
    {
        case TGContentSizeCategoryXS:
            return 11.0f;
            
        case TGContentSizeCategoryS:
            return 12.0f;
            
        case TGContentSizeCategoryL:
            return 13.0f;
            
        case TGContentSizeCategoryXL:
            return 14.0f;
            
        case TGContentSizeCategoryXXL:
            return 15.0f;
            
        case TGContentSizeCategoryXXXL:
            return 16.0f;
            
        default:
            break;
    }
    
    return 13.0f;
}

@end
