#import <Foundation/Foundation.h>


/**
    Test failure location and reason.
 
    @ingroup integration
 */
@interface HCTestFailure : NSObject

@property (nonatomic, readonly) id testCase;
@property (nonatomic, readonly) NSString *fileName;
@property (nonatomic, readonly) NSUInteger lineNumber;
@property (nonatomic, readonly) NSString *reason;

- (instancetype)initWithTestCase:(id)testCase
                        fileName:(NSString *)fileName
                      lineNumber:(NSUInteger)lineNumber
                          reason:(NSString *)reason;

@end
