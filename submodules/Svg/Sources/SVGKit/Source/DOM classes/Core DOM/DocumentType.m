//
//  DocumentType.m
//  SVGKit
//
//  Created by adam on 23/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DocumentType.h"

/*
 in case we need to redeclare them readwrite:
 @property(nonatomic,retain,readonly) NSString* name;
 @property(nonatomic,retain,readonly) NamedNodeMap* entities;
 @property(nonatomic,retain,readonly) NamedNodeMap* notations;
 
 // Introduced in DOM Level 2:
 @property(nonatomic,retain,readonly) NSString* publicId;
 
 // Introduced in DOM Level 2:
 @property(nonatomic,retain,readonly) NSString* systemId;
 
 // Introduced in DOM Level 2:
 @property(nonatomic,retain,readonly) NSString* internalSubset;

 */

@implementation DocumentType

@synthesize name;
@synthesize entities;
@synthesize notations;

// Introduced in DOM Level 2:
@synthesize publicId;

// Introduced in DOM Level 2:
@synthesize systemId;

// Introduced in DOM Level 2:
@synthesize internalSubset;


@end
