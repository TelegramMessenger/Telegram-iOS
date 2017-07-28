//
//  CBDownloadOperationDelegate.h
//  CoubPlayer
//
//  Created by Pavel Tikhonenko on 19/10/14.
//  Copyright (c) 2014 Pavel Tikhonenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CBDownloadOperationDelegate <NSObject>

@optional
- (void)downloadDidReachProgress:(float)progress;
- (void)downloadHasBeenCancelledWithError:(NSError *)error;

@end
