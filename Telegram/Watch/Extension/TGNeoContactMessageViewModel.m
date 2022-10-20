#import "TGNeoContactMessageViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGNeoLabelViewModel.h"

#import "TGStringUtils.h"

@interface TGNeoContactMessageViewModel ()
{
    TGNeoLabelViewModel *_nameModel;
    TGNeoLabelViewModel *_phoneModel;
    
    int32_t _userId;
    int32_t _ownUserId;
    NSString *_avatarUrl;
    NSString *_firstName;
    NSString *_lastName;
}
@end

@implementation TGNeoContactMessageViewModel

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super initWithMessage:message type:type users:users context:context];
    if (self != nil)
    {
        TGBridgeContactMediaAttachment *contactAttachment = nil;
        for (TGBridgeMediaAttachment *attachment in message.media)
        {
            if ([attachment isKindOfClass:[TGBridgeContactMediaAttachment class]])
            {
                contactAttachment = (TGBridgeContactMediaAttachment *)attachment;
                break;
            }
        }
        
        _nameModel = [[TGNeoLabelViewModel alloc] initWithText:[contactAttachment displayName] font:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[self normalColorForMessage:message type:type] attributes:nil];
        _nameModel.multiline = false;
        [self addSubmodel:_nameModel];
        
        _phoneModel = [[TGNeoLabelViewModel alloc] initWithText:[contactAttachment prettyPhoneNumber] font:[UIFont systemFontOfSize:12] color:[self subtitleColorForMessage:message type:type] attributes:nil];
        _phoneModel.multiline = false;
        [self addSubmodel:_phoneModel];
        
        TGBridgeUser *user = users[@(contactAttachment.uid)];
        if (user != nil)
        {
            _userId = user.identifier;
            _ownUserId = context.userId;
            _firstName = user.firstName;
            _lastName = user.lastName;
            _avatarUrl = user.photoSmall;
        }
        else
        {
            _firstName = contactAttachment.firstName;
            _lastName = contactAttachment.lastName;
        }
    }
    return self;
}

- (CGSize)layoutWithContainerSize:(CGSize)containerSize
{
    CGSize contentContainerSize = [self contentContainerSizeWithContainerSize:containerSize];
    
    CGSize headerSize = [self layoutHeaderModelsWithContainerSize:contentContainerSize];
    CGFloat maxContentWidth = headerSize.width;
    CGFloat textTopOffset = headerSize.height;
    
    CGFloat leftOffset = 19 + TGNeoBubbleMessageMetaSpacing;
    contentContainerSize = CGSizeMake(containerSize.width - TGNeoBubbleMessageViewModelInsets.left - TGNeoBubbleMessageViewModelInsets.right - leftOffset, FLT_MAX);
    
    CGSize nameSize = [_nameModel contentSizeWithContainerSize:contentContainerSize];
    CGSize phoneSize = [_phoneModel contentSizeWithContainerSize:contentContainerSize];
    maxContentWidth = MAX(maxContentWidth, MAX(nameSize.width, phoneSize.width) + leftOffset);
    
    _nameModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, textTopOffset, nameSize.width, 14);
    _phoneModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, CGRectGetMaxY(_nameModel.frame), phoneSize.width, 14);
    
    UIEdgeInsets inset = UIEdgeInsetsMake(textTopOffset + 5, TGNeoBubbleMessageViewModelInsets.left, 0, 0);
    NSDictionary *avatarDictionary;
    NSString *initials = [TGStringUtils initialsForFirstName:_firstName lastName:_lastName single:true];
    if (_userId != 0)
    {
        if (_avatarUrl.length > 0)
        {
            avatarDictionary = @{ TGNeoMessageAvatarIdentifier: @(_userId), TGNeoMessageAvatarUrl: _avatarUrl };
        }
        else
        {
            avatarDictionary = @{ TGNeoMessageAvatarColor: [TGColor colorForUserId:_userId myUserId:_ownUserId], TGNeoMessageAvatarInitials: initials };
        }
    }
    else
    {
        avatarDictionary = @{ TGNeoMessageAvatarColor: [UIColor grayColor], TGNeoMessageAvatarInitials: initials };
    }
    
    [self addAdditionalLayout:@{ TGNeoContentInset: [NSValue valueWithUIEdgeInsets:inset], TGNeoMessageAvatarGroup: avatarDictionary } withKey:TGNeoMessageMetaGroup];
    
    CGSize contentSize =  CGSizeMake(TGNeoBubbleMessageViewModelInsets.left + TGNeoBubbleMessageViewModelInsets.right + maxContentWidth, CGRectGetMaxY(_phoneModel.frame) + TGNeoBubbleMessageViewModelInsets.bottom);
    
    [super layoutWithContainerSize:contentSize];
    
    return contentSize;
}

@end
