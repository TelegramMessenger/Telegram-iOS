#import <Foundation/Foundation.h>

@interface TGBridgeBotCommandInfo : NSObject <NSCoding>
{
    NSString *_command;
    NSString *_commandDescription;
}

@property (nonatomic, readonly) NSString *command;
@property (nonatomic, readonly) NSString *commandDescription;

@end
