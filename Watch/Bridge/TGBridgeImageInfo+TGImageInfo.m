#import "TGBridgeImageInfo+TGImageInfo.h"

#import <LegacyComponents/LegacyComponents.h>

@implementation TGBridgeImageInfo (TGImageInfo)

+ (TGBridgeImageInfo *)imageInfoWithTGImageInfo:(TGImageInfo *)imageInfo
{
    if (imageInfo == nil)
        return nil;
    
    TGBridgeImageInfo *bridgeImageInfo = [[TGBridgeImageInfo alloc] init];
    NSDictionary *allSizes = imageInfo.allSizes;
    
    NSMutableArray *bridgeEntries = [[NSMutableArray alloc] init];
    for (NSString *url in allSizes.allKeys)
    {
        TGBridgeImageSizeInfo *bridgeEntry = [[TGBridgeImageSizeInfo alloc] init];
        bridgeEntry.url = url;
        bridgeEntry.dimensions = [allSizes[url] CGSizeValue];
        
        [bridgeEntries addObject:bridgeEntry];
    }
    
    bridgeImageInfo->_entries = bridgeEntries;
    
    return bridgeImageInfo;
}

+ (TGImageInfo *)tgImageInfoWithBridgeImageInfo:(TGBridgeImageInfo *)bridgeImageInfo
{
    if (bridgeImageInfo == nil)
        return nil;
    
    TGImageInfo *imageInfo = [[TGImageInfo alloc] init];
    
    for (TGBridgeImageSizeInfo *entry in bridgeImageInfo.entries)
        [imageInfo addImageWithSize:entry.dimensions url:entry.url];
    
    return imageInfo;
}

@end
