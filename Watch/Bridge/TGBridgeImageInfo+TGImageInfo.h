#import "TGBridgeImageInfo.h"

@class TGImageInfo;

@interface TGBridgeImageInfo (TGImageInfo)

+ (TGBridgeImageInfo *)imageInfoWithTGImageInfo:(TGImageInfo *)imageInfo;

+ (TGImageInfo *)tgImageInfoWithBridgeImageInfo:(TGBridgeImageInfo *)bridgeImageInfo;

@end
