#import <Foundation/Foundation.h>

@interface TGBridgeMessageEntity : NSObject <NSCoding>

@property (nonatomic, assign) NSRange range;

+ (instancetype)entitityWithRange:(NSRange)range;

@end


@interface TGBridgeMessageEntityUrl : TGBridgeMessageEntity

@end


@interface TGBridgeMessageEntityEmail : TGBridgeMessageEntity

@end


@interface TGBridgeMessageEntityTextUrl : TGBridgeMessageEntity

@end


@interface TGBridgeMessageEntityMention : TGBridgeMessageEntity

@end


@interface TGBridgeMessageEntityHashtag : TGBridgeMessageEntity

@end


@interface TGBridgeMessageEntityBotCommand : TGBridgeMessageEntity

@end


@interface TGBridgeMessageEntityBold : TGBridgeMessageEntity

@end


@interface TGBridgeMessageEntityItalic : TGBridgeMessageEntity

@end


@interface TGBridgeMessageEntityCode : TGBridgeMessageEntity

@end


@interface TGBridgeMessageEntityPre : TGBridgeMessageEntity

@end
