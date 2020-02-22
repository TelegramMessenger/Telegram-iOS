//
//  NSDictionary+Extensions.m
//  Coub
//
//  Created by Konstantin Anoshkin on 8.10.13.
//  Copyright 2013 Coub. All rights reserved.
//

#import "NSDictionary+CBExtensions.h"


@implementation NSDictionary (CBDictionaryExtensions)


- (NSString *) coubURIFromVersionTemplateWithPreferredSubstitutions: (NSArray *) preferredVersions
{
	NSString *urlTemplate = self[@"template"];
	if (urlTemplate) {
		NSArray *availableVersions = self[@"versions"];
		__block NSString *bestVersion = nil;
		[preferredVersions enumerateObjectsUsingBlock: ^(NSString *version, __unused NSUInteger idx, BOOL *stop) {
			if ([availableVersions containsObject: version]) {
				bestVersion = version;
				*stop = YES;
			}
		}];
		if (bestVersion) {
			//KALog(@"%@", [urlTemplate stringByReplacingOccurrencesOfString: @"%{version}" withString: bestVersion]);
			return [urlTemplate stringByReplacingOccurrencesOfString: @"%{version}" withString: bestVersion];
		} else {
			//KAObjectLogError(@"Could not find appropriate URI version: {%@}", [preferredVersions componentsJoinedByString: @", "]);
		}
	}
	return nil;
}


@end
