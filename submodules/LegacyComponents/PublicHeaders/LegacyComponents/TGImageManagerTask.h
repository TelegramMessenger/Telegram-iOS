#import <LegacyComponents/TGImageDataSource.h>

@interface TGImageManagerTask : NSObject
{
    @public bool _isCancelled;
}

@property (nonatomic, strong) TGImageDataSource *dataSource;
@property (nonatomic, strong) id childTaskId;

@end
