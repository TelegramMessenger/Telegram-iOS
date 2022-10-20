#import <WatchCommonWatch/WatchCommonWatch.h>

@interface TGBridgeStickerPack : NSObject <NSCoding>
{
    bool _builtIn;
    NSString *_title;
    NSArray *_documents;
}

@property (nonatomic, readonly, getter=isBuiltIn) bool builtIn;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSArray *documents;

@end
