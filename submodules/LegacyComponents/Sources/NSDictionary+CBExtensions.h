//
//  NSDictionary+Extensions.h
//  Coub
//
//  Created by Konstantin Anoshkin on 8.10.13.
//  Copyright 2013 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSDictionary (CBDictionaryExtensions)

- (NSString *) coubURIFromVersionTemplateWithPreferredSubstitutions: (NSArray *) preferredVersions;

@end
