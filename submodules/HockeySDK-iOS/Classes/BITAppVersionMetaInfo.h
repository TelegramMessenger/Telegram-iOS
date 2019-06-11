/*
 * Author: Peter Steinberger
 *         Andreas Linde
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde, Peter Steinberger.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>

@interface BITAppVersionMetaInfo : NSObject {
}
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *shortVersion;
@property (nonatomic, copy) NSString *minOSVersion;
@property (nonatomic, copy) NSString *notes;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, copy) NSNumber *size;
@property (nonatomic, copy) NSNumber *mandatory;
@property (nonatomic, copy) NSNumber *versionID;
@property (nonatomic, copy) NSDictionary *uuids;

- (NSString *)nameAndVersionString;
- (NSString *)versionString;
- (NSString *)dateString;
- (NSString *)sizeInMB;
- (NSString *)notesOrEmptyString;
- (void)setDateWithTimestamp:(NSTimeInterval)timestamp;
- (BOOL)isValid;
- (BOOL)hasUUID:(NSString *)uuid;
- (BOOL)isEqualToAppVersionMetaInfo:(BITAppVersionMetaInfo *)anAppVersionMetaInfo;

+ (BITAppVersionMetaInfo *)appVersionMetaInfoFromDict:(NSDictionary *)dict;

@end
