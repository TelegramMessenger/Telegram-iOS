@import XCTest;

#import "IDTextInputDifferentialRunner.h"
#import "IDTextInputScenario.h"

@interface IDTextInputFastLifecycleTests : XCTestCase
@end

@implementation IDTextInputFastLifecycleTests

- (NSURL *)fixtureURLNamed:(NSString *)name {
    NSString *testPath = [NSString stringWithUTF8String:__FILE__];
    NSURL *root = [NSURL fileURLWithPath:
        [[testPath stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent]
                              isDirectory:YES];
    return [[root
        URLByAppendingPathComponent:@"TestFixtures/TextInputScenarios"
                        isDirectory:YES]
        URLByAppendingPathComponent:
            [name stringByAppendingPathExtension:@"json"]];
}

- (NSArray<IDTextInputScenario *> *)scenariosNamed:(NSString *)name {
    NSError *error = nil;
    NSArray<IDTextInputScenario *> *scenarios =
        IDLoadTextInputScenarios([self fixtureURLNamed:name], &error);
    XCTAssertNotNil(scenarios, @"%@", error);
    return scenarios ?: @[];
}

- (void)assertScenario:(IDTextInputScenario *)scenario
                 order:(IDTextInputExecutionOrder)order {
    NSError *error = nil;
    IDTextInputDifferentialResult *result =
        [[IDTextInputDifferentialRunner new]
            runScenario:scenario order:order error:&error];
    XCTAssertNotNil(
        result, @"identifier=%@ order=%ld error=%@",
        scenario.identifier, (long)order, error);
    if (result == nil) return;
    XCTAssertEqual(
        result.differences.count, 0U,
        @"identifier=%@ order=%ld differences=%@",
        scenario.identifier, (long)order, result.differences);
}

- (void)testAllIMEScenariosMatchStockInBothOrders {
    NSArray<IDTextInputScenario *> *scenarios =
        [self scenariosNamed:@"ime-ios26.5-v1"];
    for (IDTextInputScenario *scenario in scenarios) {
        @autoreleasepool {
            [self assertScenario:scenario
                           order:IDTextInputExecutionOrderStockReferenceMinimal];
            [self assertScenario:scenario
                           order:IDTextInputExecutionOrderMinimalReferenceStock];
        }
    }
}

- (void)testAllAutocorrectionScenariosMatchStockInBothOrders {
    NSArray<IDTextInputScenario *> *scenarios =
        [self scenariosNamed:@"autocorrection-ios26.5-v1"];
    for (IDTextInputScenario *scenario in scenarios) {
        @autoreleasepool {
            [self assertScenario:scenario
                           order:IDTextInputExecutionOrderStockReferenceMinimal];
            [self assertScenario:scenario
                           order:IDTextInputExecutionOrderMinimalReferenceStock];
        }
    }
}

- (void)testAllInlinePredictionScenariosMatchStockInBothOrders {
    NSArray<IDTextInputScenario *> *scenarios =
        [self scenariosNamed:@"inline-prediction-ios26.5-v1"];
    for (IDTextInputScenario *scenario in scenarios) {
        @autoreleasepool {
            [self assertScenario:scenario
                           order:IDTextInputExecutionOrderStockReferenceMinimal];
            [self assertScenario:scenario
                           order:IDTextInputExecutionOrderMinimalReferenceStock];
        }
    }
}

@end
