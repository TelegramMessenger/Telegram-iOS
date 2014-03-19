//
//  BITImageAnnotation.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 24.02.14.
//
//

#import "BITImageAnnotation.h"

@implementation BITImageAnnotation

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
      //self.backgroundColor = [UIColor redColor];
    }
    return self;
}


-(BOOL)resizable {
  return NO;
}

@end
