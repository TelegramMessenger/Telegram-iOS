#import <Foundation/Foundation.h>

@interface TGIndexPath : NSObject <NSCopying>

@property (nonatomic, assign) NSUInteger section;
@property (nonatomic, assign) NSUInteger row;

+ (instancetype)indexPathForRow:(NSUInteger)row inSection:(NSUInteger)section;

@end
