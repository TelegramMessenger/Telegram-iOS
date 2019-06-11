//
//  ItemViewModel.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ItemViewModel.h"
#import <stdatomic.h>

NSArray *titles;
NSArray *firstInfos;
NSArray *badges;

@interface ItemViewModel()

@property (nonatomic, assign) NSInteger catNumber;
@property (nonatomic, assign) NSInteger labelNumber;

@end

@implementation ItemViewModel

+ (ItemViewModel *)randomItem {
  return [[ItemViewModel alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
      static _Atomic(NSInteger) nextID = ATOMIC_VAR_INIT(1);
      _identifier = atomic_fetch_add(&nextID, 1);
      _titleText = [self randomObjectFromArray:titles];
      _firstInfoText = [self randomObjectFromArray:firstInfos];
      _secondInfoText = [NSString stringWithFormat:@"%zd+ bought", [self randomNumberInRange:5 to:6000]];
      _originalPriceText = [NSString stringWithFormat:@"$%zd", [self randomNumberInRange:40 to:90]];
      _finalPriceText = [NSString stringWithFormat:@"$%zd", [self randomNumberInRange:5 to:30]];
      _soldOutText = (arc4random() % 5 == 0) ? @"SOLD OUT" : nil;
      _distanceLabelText = [NSString stringWithFormat:@"%zd mi", [self randomNumberInRange:1 to:20]];
      if (arc4random() % 2 == 0) {
        _badgeText = [self randomObjectFromArray:badges];
      }
      _catNumber = [self randomNumberInRange:1 to:10];
      _labelNumber = [self randomNumberInRange:1 to:10000];
    }
    return self;
}

- (NSURL *)imageURLWithSize:(CGSize)size
{
  NSString *imageText = [NSString stringWithFormat:@"Fun cat pic %zd", self.labelNumber];
  NSString *urlString = [NSString stringWithFormat:@"http://lorempixel.com/%zd/%zd/cats/%zd/%@",
                         (NSInteger)roundl(size.width),
                         (NSInteger)roundl(size.height), self.catNumber, imageText];

  urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
  return [NSURL URLWithString:urlString];
}

// titles courtesy of http://www.catipsum.com/
+ (void)initialize
{
  titles = @[@"Leave fur on owners clothes intrigued by the shower",
             @"Meowwww",
             @"Immediately regret falling into bathtub stare out the window",
             @"Jump launch to pounce upon little yarn mouse, bare fangs at toy run hide in litter box until treats are fed",
             @"Sleep nap",
             @"Lick butt",
             @"Chase laser lick arm hair present belly, scratch hand when stroked"];
  firstInfos = @[@"Kitty Shop",
                 @"Cat's r us",
                 @"Fantastic Felines",
                 @"The Cat Shop",
                 @"Cat in a hat",
                 @"Cat-tastic"
                 ];
  
  badges = @[@"ADORABLE",
             @"BOUNCES",
             @"HATES CUCUMBERS",
             @"SCRATCHY"
             ];
}


- (id)randomObjectFromArray:(NSArray *)strings
{
  u_int32_t ipsumCount = (u_int32_t)[strings count];
  u_int32_t location = arc4random_uniform(ipsumCount);
  
  return strings[location];
}

- (uint32_t)randomNumberInRange:(uint32_t)start to:(uint32_t)end {
  
  return start + arc4random_uniform(end - start);
}


@end
