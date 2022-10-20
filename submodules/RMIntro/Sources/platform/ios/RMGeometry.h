//
//  RMGeometry.h
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 11/19/10.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//const float extern Pi=3.14;
//const float extern Pi2=6.28;







static inline CGFloat DtoR(CGFloat a)
{
    return (CGFloat)(a*M_PI/180.0);
}


static inline CGFloat rnd(CGFloat a, CGFloat b)
{
    //return rand()%10000/10000.0*(b-a)+a;
    return (CGFloat)(arc4random()%10000/10000.0*(b-a)+a);
}

static inline NSInteger intRnd(NSInteger a, NSInteger b)
{
    //return rand()%(b-a+1)+a;
    return arc4random()%(b-a+1)+a;
}

static inline NSInteger signRnd()
{
    return intRnd(0, 1)*2-1;
}

static inline NSInteger sign(CGFloat a)
{
    return a >= 0 ? 1 : -1;
}


static inline CGPoint CGRectCenter(CGRect rect) {
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

static inline CGRect CGRectCentralize(CGRect rect, CGPoint center) {
    CGPoint oldCenter = CGRectCenter(rect);
    CGPoint offset = CGPointMake(center.x - oldCenter.x, center.y - oldCenter.y); 
    
    return CGRectOffset(rect, offset.x, offset.y);
}

static inline CGRect CGRectRoundComponents(CGRect rect) {
    return CGRectMake((NSInteger) (rect.origin.x + 0.5), (NSInteger) (rect.origin.y + 0.5), (NSInteger) (rect.size.width + 0.5), (NSInteger) (rect.size.height + 0.5));
}

static inline CGRect CGRectScaledToWidth (CGRect rect, CGFloat width) {    
    const CGFloat ratio = width / rect.size.width;
    return CGRectMake(rect.origin.x, rect.origin.y, width, rect.size.height * ratio);
}

static inline CGRect CGRectScaledToHeight(CGRect rect, CGFloat height) {
    const CGFloat ratio = height / rect.size.height;
    return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width * ratio, height);
}

static inline CGRect CGRectScaledToWidthI (CGRect rect, CGFloat width) {
    const CGFloat ratio = width / rect.size.width;
    return CGRectMake((NSInteger) rect.origin.x, (NSInteger) rect.origin.y, (NSInteger) width, (NSInteger) (rect.size.height * ratio));
}

static inline CGRect CGRectScaledToHeightI(CGRect rect, CGFloat height) {
    const CGFloat ratio = height / rect.size.height;
    return CGRectMake((NSInteger) rect.origin.x, (NSInteger) rect.origin.y, (NSInteger) (rect.size.width * ratio), (NSInteger) height);
}

static inline CGRect CGRectScaledToFitRect(CGRect innerRect, CGRect boundingRect, BOOL centralize) {
    const CGFloat innerRectWHRatio = innerRect.size.width / innerRect.size.height;
    const CGFloat boundingRectWHRatio = boundingRect.size.width / boundingRect.size.height;
    
    CGRect result;
    if (innerRectWHRatio >= boundingRectWHRatio) {
        result = CGRectScaledToWidth(innerRect, boundingRect.size.width);
    } else {
        result = CGRectScaledToHeight(innerRect, boundingRect.size.height);
    }
    
    if (centralize) {
        result = CGRectCentralize(result, CGRectCenter(boundingRect));
    }
    
    result = CGRectRoundComponents(result);
    
    return result;
}

static inline CGRect CGRectScaledToFitRectSmall(CGRect innerRect, CGRect boundingRect, BOOL centralize) {
    const CGFloat innerRectWHRatio = innerRect.size.width / innerRect.size.height;
    const CGFloat boundingRectWHRatio = boundingRect.size.width / boundingRect.size.height;
    
    CGRect result;
    
    if (innerRect.size.width<boundingRect.size.width && innerRect.size.height<boundingRect.size.height) {
        result=CGRectCentralize(innerRect, CGRectCenter(boundingRect));
    }
    else
    {
        if (innerRectWHRatio >= boundingRectWHRatio) {
            result = CGRectScaledToWidth(innerRect, boundingRect.size.width);
        } else {
            result = CGRectScaledToHeight(innerRect, boundingRect.size.height);
        }
        
        if (centralize) {
            result = CGRectCentralize(result, CGRectCenter(boundingRect));
        }
        
        
    
    }

    result = CGRectRoundComponents(result);
    
    return result;
}



static inline CGRect CGRectScaledToFitRectI(CGRect innerRect, CGRect boundingRect, BOOL centralize) {
    return CGRectRoundComponents(CGRectScaledToFitRect(innerRect, boundingRect, centralize));
}

static inline CGRect  CGRectMakeOrigAndSize(CGPoint orig, CGSize size) {
    return CGRectMake(orig.x, orig.y, size.width, size.height);
}

static inline CGRect  CGRectChangedWidth(CGRect rect, CGFloat width) {
    return CGRectMake(rect.origin.x, rect.origin.y, width, rect.size.height);
}

static inline CGRect  CGRectChangedHeight(CGRect rect, CGFloat height) {
    return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, height);
}

static inline CGRect  CGRectChangedSize(CGRect rect, CGSize size) {
    return CGRectMake(rect.origin.x, rect.origin.y, size.width, size.height);
}

static inline CGRect  CGRectChangedOrigin(CGRect rect, CGPoint origin) {
    return CGRectMake(origin.x, origin.y, rect.size.width, rect.size.height);
}

static inline CGRect  CGRectChangedOriginX(CGRect rect, CGFloat originX) {
    return CGRectMake(originX, rect.origin.y, rect.size.width, rect.size.height);
}

static inline CGRect  CGRectChangedOriginY(CGRect rect, CGFloat originY) {
    return CGRectMake(rect.origin.x, originY, rect.size.width, rect.size.height);
}

static inline CGRect  CGRectChangedCenterY(CGRect rect, CGFloat centerY) {
    return CGRectMake(rect.origin.x, centerY - rect.size.height / 2.0f, rect.size.width, rect.size.height);
}

static inline CGRect  CGRectChangedCenterX(CGRect rect, CGFloat centerX) {
    return CGRectMake(centerX - rect.size.width / 2.0f, rect.origin.y, rect.size.width, rect.size.height);
}


static inline CGRect  CGRectWithIndent(CGRect rect, NSInteger indent) {
    return CGRectMake(rect.origin.x-indent, rect.origin.y-indent, rect.size.width+indent*2,rect.size.height+indent*2);
}

#define VK_ROUND_RECT(rect) rect = CGRectRoundComponents(rect)
