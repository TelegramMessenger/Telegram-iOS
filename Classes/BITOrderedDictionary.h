#import <Foundation/Foundation.h>
#import "HockeySDKNullability.h"

NS_ASSUME_NONNULL_BEGIN
@interface BITOrderedDictionary : NSMutableDictionary {
  NSMutableDictionary *dictionary;
  NSMutableArray *order;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (void)setObject:(id)anObject forKey:(id)aKey;

@end
NS_ASSUME_NONNULL_END
