//
//  RMIntroPageView.h
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 05.12.13.
//  Copyright (c) 2013 Ilya Rimchikov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RMIntroPageView : UIView
{
    NSString *_headline;
    NSMutableAttributedString *_description;
}

- (id)initWithFrame:(CGRect)frame headline:(NSString*)headline description:(NSString*)description color:(UIColor *)color;

@end
