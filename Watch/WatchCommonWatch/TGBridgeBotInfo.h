#import <Foundation/Foundation.h>

@interface TGBridgeBotInfo : NSObject <NSCoding>
{
    NSString *_shortDescription;
    NSArray *_commandList;
}

@property (nonatomic, readonly) NSString *shortDescription;
@property (nonatomic, readonly) NSArray *commandList;

@end
