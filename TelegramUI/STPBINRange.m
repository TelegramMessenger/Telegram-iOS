//
//  STPBINRange.m
//  Stripe
//
//  Created by Jack Flintermann on 5/24/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPBINRange.h"
#import "NSString+Stripe.h"

@interface STPBINRange()

@property(nonatomic)NSUInteger length;
@property(nonatomic)NSString *qRangeLow;
@property(nonatomic)NSString *qRangeHigh;
@property(nonatomic)STPCardBrand brand;

- (BOOL)matchesNumber:(NSString *)number;

@end


@implementation STPBINRange

+ (NSArray<STPBINRange *> *)allRanges {
    
    static NSArray<STPBINRange *> *STPBINRangeAllRanges;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *ranges = @[
                            // Catch-all values
                            @[@"", @"", @16, @(STPCardBrandUnknown)],
                            @[@"34", @"34", @15, @(STPCardBrandAmex)],
                            @[@"37", @"37", @15, @(STPCardBrandAmex)],
                            @[@"30", @"30", @14, @(STPCardBrandDinersClub)],
                            @[@"36", @"36", @14, @(STPCardBrandDinersClub)],
                            @[@"38", @"39", @14, @(STPCardBrandDinersClub)],
                            @[@"6011", @"6011", @16, @(STPCardBrandDiscover)],
                            @[@"622", @"622",   @16, @(STPCardBrandDiscover)],
                            @[@"64", @"65",     @16, @(STPCardBrandDiscover)],
                            @[@"35", @"35", @16, @(STPCardBrandJCB)],
                            @[@"5", @"5", @16, @(STPCardBrandMasterCard)],
                            @[@"4", @"4", @16, @(STPCardBrandVisa)],
                            // Specific known BIN ranges
                            @[@"222100", @"272099", @16, @(STPCardBrandMasterCard)],
                            
                            @[@"413600", @"413600", @13, @(STPCardBrandVisa)],
                            @[@"444509", @"444509", @13, @(STPCardBrandVisa)],
                            @[@"444509", @"444509", @13, @(STPCardBrandVisa)],
                            @[@"444550", @"444550", @13, @(STPCardBrandVisa)],
                            @[@"450603", @"450603", @13, @(STPCardBrandVisa)],
                            @[@"450617", @"450617", @13, @(STPCardBrandVisa)],
                            @[@"450628", @"450629", @13, @(STPCardBrandVisa)],
                            @[@"450636", @"450636", @13, @(STPCardBrandVisa)],
                            @[@"450640", @"450641", @13, @(STPCardBrandVisa)],
                            @[@"450662", @"450662", @13, @(STPCardBrandVisa)],
                            @[@"463100", @"463100", @13, @(STPCardBrandVisa)],
                            @[@"476142", @"476142", @13, @(STPCardBrandVisa)],
                            @[@"476143", @"476143", @13, @(STPCardBrandVisa)],
                            @[@"492901", @"492902", @13, @(STPCardBrandVisa)],
                            @[@"492920", @"492920", @13, @(STPCardBrandVisa)],
                            @[@"492923", @"492923", @13, @(STPCardBrandVisa)],
                            @[@"492928", @"492930", @13, @(STPCardBrandVisa)],
                            @[@"492937", @"492937", @13, @(STPCardBrandVisa)],
                            @[@"492939", @"492939", @13, @(STPCardBrandVisa)],
                            @[@"492960", @"492960", @13, @(STPCardBrandVisa)],
                            ];
        NSMutableArray *binRanges = [NSMutableArray array];
        for (NSArray *range in ranges) {
            STPBINRange *binRange = [self.class new];
            binRange.qRangeLow  = range[0];
            binRange.qRangeHigh = range[1];
            binRange.length     = [range[2] unsignedIntegerValue];
            binRange.brand = [range[3] integerValue];
            [binRanges addObject:binRange];
        }
        STPBINRangeAllRanges = [binRanges copy];
    });
    return STPBINRangeAllRanges;
}

- (BOOL)matchesNumber:(NSString *)number {
    NSString *low = [number stringByPaddingToLength:self.qRangeLow.length withString:@"0" startingAtIndex:0];
    NSString *high = [number stringByPaddingToLength:self.qRangeHigh.length withString:@"0" startingAtIndex:0];
    
    return self.qRangeLow.integerValue <= low.integerValue && self.qRangeHigh.integerValue >= high.integerValue;
}

- (NSComparisonResult)compare:(STPBINRange *)other {
    return [@(self.qRangeLow.length) compare:@(other.qRangeLow.length)];
}

+ (NSArray<STPBINRange *> *)binRangesForNumber:(NSString *)number {
    return [[self allRanges] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(STPBINRange *range, __unused NSDictionary *bindings) {
        return [range matchesNumber:number];
    }]];
}

+ (instancetype)mostSpecificBINRangeForNumber:(NSString *)number {
    NSArray *validRanges = [[self allRanges] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(STPBINRange *range, __unused NSDictionary *bindings) {
        return [range matchesNumber:number];
    }]];
    return [[validRanges sortedArrayUsingSelector:@selector(compare:)] lastObject];
}

+ (NSArray<STPBINRange *> *)binRangesForBrand:(STPCardBrand)brand {
    return [[self allRanges] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(STPBINRange *range, __unused NSDictionary *bindings) {
        return range.brand == brand;
    }]];
}

@end
