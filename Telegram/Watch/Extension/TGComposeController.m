#import "TGComposeController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGBridgeSendMessageSignals.h"

#import "WKInterfaceGroup+Signals.h"
#import "TGBridgeMediaSignals.h"

#import "TGContactsController.h"
#import "TGInputController.h"
#import "TGStickersController.h"
#import "TGLocationController.h"

NSString *const TGComposeControllerIdentifier = @"TGComposeController";

@interface TGComposeController ()
{
    TGBridgeUser *_recipient;
    NSString *_messageText;
    TGBridgeDocumentMediaAttachment *_messageSticker;
    TGBridgeLocationMediaAttachment *_messageLocation;

    SMetaDisposable *_sendMessageDisposable;
}
@end

@implementation TGComposeController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _sendMessageDisposable = [[SMetaDisposable alloc] init];
        [self.locationIcon _setInitialHidden:true];
        [self.stickerGroup _setInitialHidden:true];
    }
    return self;
}

- (void)dealloc
{
    [_sendMessageDisposable dispose];
}

- (void)configureWithContext:(id<TGInterfaceContext>)__unused context
{
    self.recipientLabel.text = TGLocalized(@"Watch.Compose.AddContact");
    self.messageLabel.text = TGLocalized(@"Watch.Compose.CreateMessage");
    [self setSendButtonEnabled:false];
}

- (void)willActivate
{
    [super willActivate];
    
    [self.stickerGroup updateIfNeeded];
}

- (void)didDeactivate
{
    [super didDeactivate];
}

- (IBAction)addContactPressedAction
{
    [TGInputController presentPlainInputControllerForInterfaceController:self completion:^(NSString *text)
    {
        __weak TGComposeController *weakSelf = self;
        
        TGContactsControllerContext *context = [[TGContactsControllerContext alloc] initWithQuery:text];
        context.completionBlock = ^(TGBridgeUser *contact)
        {
            __strong TGComposeController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf setRecipient:contact];
        };
        
        [self presentControllerWithClass:[TGContactsController class] context:context];
    }];
}

- (IBAction)createMessagePressedAction
{
    [TGInputController presentInputControllerForInterfaceController:self suggestionsForText:nil completion:^(NSString *text)
    {
        [self setMessageText:text];
    }];
}

- (IBAction)stickerPressedAction
{
    __weak TGComposeController *weakSelf = self;
    TGStickersControllerContext *context = [[TGStickersControllerContext alloc] init];
    context.completionBlock = ^(TGBridgeDocumentMediaAttachment *sticker)
    {
        __strong TGComposeController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setMessageSticker:sticker];
    };
    [self presentControllerWithClass:[TGStickersController class] context:context];
}

- (IBAction)locationPressedAction
{
    __weak TGComposeController *weakSelf = self;
    TGLocationControllerContext *context = [[TGLocationControllerContext alloc] init];
    context.completionBlock = ^(TGBridgeLocationMediaAttachment *location)
    {
        __strong TGComposeController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setMessageLocation:location];
    };
    [self presentControllerWithClass:[TGLocationController class] context:context];
}

- (IBAction)sendPressedAction
{
    __weak TGComposeController *weakSelf = self;
    if (_messageSticker != nil)
    {
        [_sendMessageDisposable setDisposable:[[TGBridgeSendMessageSignals sendMessageWithPeerId:_recipient.identifier sticker:_messageSticker replyToMid:0] startWithNext:^(id next)
        {
            __strong TGComposeController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf dismissController];
        } completed:^
        {
            
        }]];
    }
    else if (_messageLocation != nil)
    {
        [_sendMessageDisposable setDisposable:[[TGBridgeSendMessageSignals sendMessageWithPeerId:_recipient.identifier location:_messageLocation replyToMid:0] startWithNext:^(id next)
        {
            __strong TGComposeController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf dismissController];
        } completed:^
        {
            
        }]];
    }
    else if (_messageText != nil)
    {
        [_sendMessageDisposable setDisposable:[[TGBridgeSendMessageSignals sendMessageWithPeerId:_recipient.identifier text:_messageText replyToMid:0] startWithNext:^(id next)
        {
            __strong TGComposeController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf dismissController];
        } completed:^{
            
        }]];
    }
}

- (void)setRecipient:(TGBridgeUser *)recipient
{
    _recipient = recipient;
    
    [self performInterfaceUpdate:^(bool animated)
    {
        if (recipient != nil)
        {
            self.recipientLabel.text = [recipient displayName];
            self.recipientLabel.textColor = [UIColor whiteColor];
        }
        else
        {
            self.recipientLabel.text = TGLocalized(@"Watch.Compose.AddContact");
            self.recipientLabel.textColor = [UIColor hexColor:0xaeb4bf];
        }
        
        [self updateSendButtonEnabled];
    }];
}

- (void)setMessageText:(NSString *)messageText
{
    _messageSticker = nil;
    _messageLocation = nil;
    
    _messageText = messageText;
    
    [self performInterfaceUpdate:^(bool animated)
    {
        self.stickerGroup.hidden = true;
        self.locationIcon.hidden = true;
        self.messageLabel.hidden = false;
        
        if (messageText.length > 0)
        {
            self.messageLabel.text = messageText;
            self.messageLabel.textColor = [UIColor whiteColor];
        }
        else
        {
            self.messageLabel.text = TGLocalized(@"Watch.Compose.CreateMessage");
            self.messageLabel.textColor = [UIColor hexColor:0xaeb4bf];
        }
        
        [self updateSendButtonEnabled];
    }];
}

- (void)setMessageSticker:(TGBridgeDocumentMediaAttachment *)messageSticker
{
    _messageText = nil;
    _messageLocation = nil;
    
    _messageSticker = messageSticker;
    
    [self performInterfaceUpdate:^(bool animated)
    {
        self.stickerGroup.hidden = false;
        self.locationIcon.hidden = true;
        self.messageLabel.hidden = true;
        self.messageLabel.text = @"";
        
        __weak TGComposeController *weakSelf = self;
        [self.stickerGroup setBackgroundImageSignal:[TGBridgeMediaSignals stickerWithDocumentId:messageSticker.documentId packId:messageSticker.stickerPackId accessHash:messageSticker.stickerPackAccessHash type:TGMediaStickerImageTypeInput] isVisible:^bool
        {
            __strong TGComposeController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return false;
            
            return strongSelf.isVisible;
        }];
        
        [self updateSendButtonEnabled];
    }];
}

- (void)setMessageLocation:(TGBridgeLocationMediaAttachment *)messageLocation
{
    _messageText = nil;
    _messageSticker = nil;
    
    _messageLocation = messageLocation;
    
    [self performInterfaceUpdate:^(bool animated)
    {
        self.stickerGroup.hidden = true;
        self.locationIcon.hidden = false;
        self.messageLabel.hidden = false;
        
        if (messageLocation.venue != nil)
            self.messageLabel.text = messageLocation.venue.title;
        else
            self.messageLabel.text = TGLocalized(@"Watch.Compose.CurrentLocation");
        self.messageLabel.textColor = [UIColor hexColor:0xaeb4bf];
        
        [self updateSendButtonEnabled];
    }];
}

- (void)setSendButtonEnabled:(bool)enabled
{
    NSAttributedString *buttonTitle = [[NSAttributedString alloc] initWithString:TGLocalized(@"Watch.Compose.Send") attributes:@{ NSForegroundColorAttributeName:enabled ? [UIColor hexColor:0x2094fa] : [UIColor hexColor:0xaeb4bf], NSFontAttributeName: [UIFont systemFontOfSize:15] }];

    self.sendButton.enabled = enabled;
    self.sendButton.attributedTitle = buttonTitle;
}

- (void)updateSendButtonEnabled
{
    bool hasRecipient = (_recipient != nil);
    bool hasContent = (_messageText.length > 0 || _messageSticker != nil || _messageLocation != nil);
    
    [self setSendButtonEnabled:hasRecipient && hasContent];
}

+ (NSString *)identifier
{
    return TGComposeControllerIdentifier;
}

@end
