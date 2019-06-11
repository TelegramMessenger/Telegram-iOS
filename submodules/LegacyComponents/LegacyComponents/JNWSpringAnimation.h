/*
 Copyright (c) 2013, Jonathan Willing. All rights reserved.
 Licensed under the MIT license <http://opensource.org/licenses/MIT>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 documentation files (the "Software"), to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
 to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
 TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 IN THE SOFTWARE.
 */

#import <QuartzCore/QuartzCore.h>

// Adds the ability to add spring to your animations.
//
// Duration cannot be set directly. Instead, duration is
// a side effect of changing the various properties below.
//
// Although JNWSpringAnimation is a subclass of CAKeyframeAnimation,
// it should be treated as if it were a subclass of CABasicAnimation.
@interface JNWSpringAnimation : CAKeyframeAnimation

// The dedicated initializer for the animation.
//
// Not all layer properties can be animated. The following are compatible:
// - position
// - position.{x, y}
// - cornerRadius
// - shadowRadius
// - bounds
// - bounds.size
// - transform.translation.{x, y, z}
// - transform.rotation.{x, y, z}
// - transform.scale.{x, y, z}
// - transform.translation
// - transform (** experimental, only performs linear interpolation on all components **)
+ (instancetype)animationWithKeyPath:(NSString *)path;

// A damped spring can be modeled with the following equation:
// F = - kx - bv
// where k is the spring constant, x is the distance from equilibrium,
// and b is the coefficient of damping.
//
// Under the hood, a damped harmonic oscillation equation is used to
// provide the same results as the data obtained from Hooke's law.

// The spring constant.
//
// Defaults to 300.
@property (nonatomic, assign) CGFloat stiffness;
@property (nonatomic, assign) CGFloat durationFactor;

// The coefficient of damping.
//
// Defaults to 30.
@property (nonatomic, assign) CGFloat damping;

// The mass of the object.
//
// Defaults to 5.
@property (nonatomic, assign) CGFloat mass;

// Equivalent to CABasicAnimation's counterparts.
//
// Both must be non-nil.
@property (nonatomic, strong) id fromValue;
@property (nonatomic, strong) id toValue;
@property (nonatomic, strong) id initialVelocity;

// The duration, which is derived from the stiffness, damping, mass, and values.
//
// Note that this property will only return a non-zero value if both the `fromValue`
// and the `toValue` properties have both been set.
//
// Defaults to 0 if no from or to values have been set.
@property (nonatomic, assign, readonly) CFTimeInterval duration;

@end
