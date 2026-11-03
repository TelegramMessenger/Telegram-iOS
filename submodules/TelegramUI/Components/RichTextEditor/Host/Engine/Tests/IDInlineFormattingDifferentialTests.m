@import XCTest;

#import "IDTextInputDifferentialRunner.h"
#import "IDTextInputScenario.h"

@interface IDInlineFormattingDifferentialTests : XCTestCase
@end

@implementation IDInlineFormattingDifferentialTests

- (NSURL *)fixtureURL {
    NSString *testPath = [NSString stringWithUTF8String:__FILE__];
    NSURL *root = [NSURL fileURLWithPath:
        [[testPath stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent]
                              isDirectory:YES];
    return [root URLByAppendingPathComponent:
        @"TestFixtures/TextInputScenarios/inline-formatting-ios26.5-v1.json"];
}

- (NSArray<IDTextInputScenario *> *)scenarios {
    NSError *error = nil;
    NSArray<IDTextInputScenario *> *scenarios =
        IDLoadTextInputScenarios(self.fixtureURL, &error);
    XCTAssertNotNil(scenarios, @"%@", error);
    XCTAssertNil(error);
    return scenarios ?: @[];
}

- (NSSet<NSString *> *)expectedIdentifiers {
    return [NSSet setWithArray:@[
        @"caret-bold-type",
        @"caret-bold-return-type",
        @"caret-combined-traits",
        @"caret-move-away",
        @"single-range-add-remove",
        @"mixed-range-global-add",
        @"cross-block-bold",
        @"cross-block-underline",
        @"replace-selected-formatted-range",
        @"delete-run-boundary",
        @"backspace-block-boundary",
        @"undo-range-format",
        @"redo-range-format",
        @"undo-formatted-typing",
    ]];
}

- (void)testFixtureContainsExactSemanticFormattingMatrix {
    NSArray<IDTextInputScenario *> *scenarios = self.scenarios;
    XCTAssertEqual(scenarios.count, 14U);
    XCTAssertEqualObjects(
        [NSSet setWithArray:[scenarios valueForKey:@"identifier"]],
        self.expectedIdentifiers);
    for (IDTextInputScenario *scenario in scenarios) {
        XCTAssertEqual(scenario.family,
                       IDTextInputScenarioFamilyInlineFormatting);
        XCTAssertTrue([scenario.comparisonFields
            containsObject:@"typingInlineTraits"]);
        XCTAssertTrue([scenario.comparisonFields
            containsObject:@"inlineRuns"]);
    }
}

- (void)testEverySemanticFormattingScenarioMatchesInBothOrders {
    IDTextInputDifferentialRunner *runner =
        [IDTextInputDifferentialRunner new];
    for (IDTextInputScenario *scenario in self.scenarios) {
        for (NSNumber *order in @[
                 @(IDTextInputExecutionOrderStockReferenceMinimal),
                 @(IDTextInputExecutionOrderMinimalReferenceStock),
             ]) {
            NSError *error = nil;
            IDTextInputDifferentialResult *result =
                [runner runScenario:scenario
                              order:order.integerValue
                              error:&error];
            XCTAssertNotNil(result, @"%@ %@: %@",
                            scenario.identifier, order, error);
            XCTAssertNil(error);
            XCTAssertEqual(
                result.differences.count, 0U,
                @"%@ %@ differences=%@",
                scenario.identifier, order, result.differences);
        }
    }
}

@end
