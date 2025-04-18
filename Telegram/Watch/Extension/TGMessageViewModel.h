#import <WatchKit/WatchKit.h>

@class TGBridgeContext;
@class TGBridgeUser;
@class TGBridgeMessage;
@class TGBridgeMediaAttachment;
@class TGBridgeActionMediaAttachment;
@class TGBridgeForwardedMessageMediaAttachment;
@class TGBridgeReplyMessageMediaAttachment;

@interface TGMessageViewModel : NSObject

+ (void)updateAuthorLabel:(WKInterfaceLabel *)authorLabel isOutgoing:(bool)isOutgoing isGroup:(bool)isGroup user:(TGBridgeUser *)user ownUserId:(int32_t)ownUserId;

+ (void)updateMediaGroup:(WKInterfaceGroup *)mediaGroup activityIndicator:(WKInterfaceImage *)activityIndicator attachment:(TGBridgeMediaAttachment *)mediaAttachment message:(TGBridgeMessage *)message notification:(bool)notification currentPhoto:(int64_t *)currentPhoto standalone:(bool)standalone margin:(CGFloat)margin imageSize:(CGSize *)imageSize isVisible:(bool (^)(void))isVisible completion:(void (^)(void))completion;

+ (void)updateForwardHeaderGroup:(WKInterfaceObject *)forwardHeaderGroup titleLabel:(WKInterfaceLabel *)titleLabel fromLabel:(WKInterfaceLabel *)fromLabel forwardAttachment:(TGBridgeForwardedMessageMediaAttachment *)forwardAttachment forwardPeer:(id)forwardPeer textColor:(UIColor *)textColor;

+ (void)updateReplyHeaderGroup:(WKInterfaceGroup *)replyHeaderGroup authorLabel:(WKInterfaceLabel *)authorLabel imageGroup:(WKInterfaceGroup *)imageGroup textLabel:(WKInterfaceLabel *)textLabel titleColor:(UIColor *)titleColor subtitleColor:(UIColor *)subtitleColor replyAttachment:(TGBridgeReplyMessageMediaAttachment *)replyAttachment currentReplyPhoto:(int64_t *)currentReplyPhoto isVisible:(bool (^)(void))isVisible completion:(void (^)(void))completion;

+ (void)imageBubbleSizeForImageSize:(CGSize)imageSize minSize:(CGSize)minSize maxSize:(CGSize)maxSize thumbnailSize:(out CGSize *)thumbnailSize renderSize:(out CGSize *)renderSize;

+ (NSAttributedString *)attributedTextForMessage:(TGBridgeMessage *)message fontSize:(CGFloat)fontSize textColor:(UIColor *)textColor;
+ (NSString *)stringForActionAttachment:(TGBridgeActionMediaAttachment *)actionAttachment message:(TGBridgeMessage *)message users:(NSDictionary *)users forChannel:(bool)forChannel;

@end

@interface TGStickerViewModel : NSObject

+ (void)updateWithMessage:(TGBridgeMessage *)message notification:(bool)notification isGroup:(bool)isGroup context:(TGBridgeContext *)context currentDocumentId:(int64_t *)currentDocumentId authorLabel:(WKInterfaceLabel *)authorLabel imageGroup:(WKInterfaceGroup *)imageGroup isVisible:(bool (^)(void))isVisible completion:(void (^)(void))completion;

@end
