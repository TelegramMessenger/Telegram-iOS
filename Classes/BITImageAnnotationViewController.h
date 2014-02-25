//
//  BITImageAnnotationViewController.h
//  HockeySDK
//
//  Created by Moritz Haarmann on 14.02.14.
//
//

#import <UIKit/UIKit.h>

@class BITImageAnnotationViewController;

@protocol BITImageAnnotationDelegate <NSObject>

- (void)annotationControllerDidCancel:(BITImageAnnotationViewController *)annotationController;
- (void)annotationController:(BITImageAnnotationViewController *)annotationController didFinishWithImage:(UIImage *)image;

@end

@interface BITImageAnnotationViewController : UIViewController

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, weak) id<BITImageAnnotationDelegate> delegate;

@end
