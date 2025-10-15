#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>
#import <LegacyComponents/TGBotComandInfo.h>

@interface TGBotInfo : NSObject <PSCoding>

@property (nonatomic, readonly) int32_t version;
@property (nonatomic, strong, readonly) NSString *shortDescription;
@property (nonatomic, strong, readonly) NSString *botDescription;
@property (nonatomic, strong, readonly) NSArray *commandList;

- (instancetype)initWithVersion:(int32_t)version shortDescription:(NSString *)shortDescription botDescription:(NSString *)botDescription commandList:(NSArray *)commandList;

@end
