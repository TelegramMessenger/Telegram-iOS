//
//  CALayer+RecursiveClone.h
//  SVGKit-iOS
//
//  Created by adam on 22/04/2013.
//  Copyright (c) 2013 na. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface CALayer (RecursiveClone)

/** Since Apple decided not to expose this common and essential method ... */
-(CALayer*) cloneRecursively;

/** Clones ONLY this layer - none of the sublayers - but uses identical code to cloneRecursively */
-(CALayer*) cloneShallow;

@end
