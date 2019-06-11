//
//  timing.h
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 03/05/14.
//  Copyright (c) 2014 IntroOpenGL. All rights reserved.
//


typedef enum
{
    Default=0,
    EaseIn=1,
    EaseOut=2,
    EaseInEaseOut=3,
    Linear=4,
    Sin=5,
    EaseOutBounce,
    TIMING_NUM
} timing_type;

float timing(float x, timing_type type);