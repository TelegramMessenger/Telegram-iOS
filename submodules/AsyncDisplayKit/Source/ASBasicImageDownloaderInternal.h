//
//  ASBasicImageDownloaderInternal.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

@interface ASBasicImageDownloaderContext : NSObject

+ (ASBasicImageDownloaderContext *)contextForURL:(NSURL *)URL;

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, weak) NSURLSessionTask *sessionTask;

- (BOOL)isCancelled;
- (void)cancel;

@end
