#import <Foundation/Foundation.h>
#import <MtProtoKit/MTProtoPersistenceInterface.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTProtoEngine : NSObject

- (instancetype)initWithPersistenceInterface:(id<MTProtoPersistenceInterface>)persistenceInterface;

@end

NS_ASSUME_NONNULL_END

