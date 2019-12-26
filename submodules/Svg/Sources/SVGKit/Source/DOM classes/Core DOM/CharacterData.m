//
//  CharacterData.m
//  SVGKit
//
//  Created by adam on 22/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CharacterData.h"

@implementation CharacterData

@synthesize data;

@synthesize length;


-(NSString*) substringData:(unsigned long) offset count:(unsigned long) count
{
	NSAssert( FALSE, @"Not implemented yet" );
	return nil;
}

-(void) appendData:(NSString*) arg
{
	NSAssert( FALSE, @"Not implemented yet" );
}
-(void) insertData:(unsigned long) offset arg:(NSString*) arg
{
	NSAssert( FALSE, @"Not implemented yet" );
}
-(void) deleteData:(unsigned long) offset count:(unsigned long) count
{
	NSAssert( FALSE, @"Not implemented yet" );
}
-(void) replaceData:(unsigned long) offset count:(unsigned long) count arg:(NSString*) arg
{
	NSAssert( FALSE, @"Not implemented yet" );
}

@end
