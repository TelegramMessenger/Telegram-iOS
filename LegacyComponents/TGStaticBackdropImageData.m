#import "TGStaticBackdropImageData.h"

NSString *TGStaticBackdropMessageActionCircle = @"TGStaticBackdropMessageActionCircle";
NSString *TGStaticBackdropMessageTimestamp = @"TGStaticBackdropMessageTimestamp";
NSString *TGStaticBackdropMessageAdditionalData = @"TGStaticBackdropMessageAdditionalData";

@interface TGStaticBackdropImageData ()
{
    NSMutableDictionary *_areas;
}

@end

@implementation TGStaticBackdropImageData

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _areas = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (TGStaticBackdropAreaData *)backdropAreaForKey:(NSString *)key
{
    if (key == nil)
        return nil;
    
    return _areas[key];
}

- (void)setBackdropArea:(TGStaticBackdropAreaData *)backdropArea forKey:(NSString *)key
{
    if (key != nil)
    {
        if (backdropArea == nil)
            [_areas removeObjectForKey:key];
        else
            _areas[key] = backdropArea;
    }
}

@end
