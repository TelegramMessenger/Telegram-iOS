#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

#import <LegacyComponents/TGBotReplyMarkupButton.h>

@interface TGBotReplyMarkupRow : NSObject <PSCoding, NSCoding>

@property (nonatomic, strong, readonly) NSArray *buttons;

- (instancetype)initWithButtons:(NSArray *)buttons;

@end
