#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

@interface TGBotComandInfo : NSObject <PSCoding>

@property (nonatomic, strong, readonly) NSString *command;
@property (nonatomic, strong, readonly) NSString *commandDescription;

- (instancetype)initWithCommand:(NSString *)command commandDescription:(NSString *)commandDescription;

@end
