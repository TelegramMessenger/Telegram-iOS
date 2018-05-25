#import <LegacyComponents/TGMediaAssetsUtils.h>

#import "LegacyComponentsInternal.h"
#import "TGStringUtils.h"
#import "TGDateUtils.h"

#import <LegacyComponents/UICollectionView+Utils.h>

#import <LegacyComponents/TGMediaSelectionContext.h>

#import <LegacyComponents/TGMediaAssetsLibrary.h>
#import <LegacyComponents/TGProgressWindow.h>

@interface TGMediaAssetsPreheatMixin ()
{
    UICollectionView *_collectionView;
    UICollectionViewScrollDirection _scrollDirection;
    
    CGRect _previousPreheatRect;
}
@end

@implementation TGMediaAssetsPreheatMixin

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView scrollDirection:(UICollectionViewScrollDirection)scrollDirection
{
    self = [super init];
    if (self != nil)
    {
        _collectionView = collectionView;
        _scrollDirection = scrollDirection;
    }
    return self;
}

- (void)update
{
    CGRect preheatRect = _collectionView.bounds;
    CGFloat delta = 0.0f;
    CGFloat threshold = 0.0f;
    switch (_scrollDirection)
    {
        case UICollectionViewScrollDirectionHorizontal:
            preheatRect = CGRectInset(preheatRect, -0.5f * preheatRect.size.width, 0.0f);
            delta = (CGFloat)(fabs(CGRectGetMidX(preheatRect) - CGRectGetMidX(_previousPreheatRect)));
            threshold = _collectionView.bounds.size.width / 3.0f;
            break;
            
        case UICollectionViewScrollDirectionVertical:
            preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * preheatRect.size.height);
            delta = (CGFloat)(fabs(CGRectGetMidY(preheatRect) - CGRectGetMidY(_previousPreheatRect)));
            threshold = _collectionView.bounds.size.height / 3.0f;
            break;
    }
    
    if (delta > threshold)
    {
        NSMutableArray *addedIndexPaths = [[NSMutableArray alloc] init];
        NSMutableArray *removedIndexPaths = [[NSMutableArray alloc] init];
        
        __weak TGMediaAssetsPreheatMixin *weakSelf = self;
        [_collectionView computeDifferenceBetweenRect:_previousPreheatRect andRect:preheatRect direction:_scrollDirection removedHandler:^(CGRect removedRect)
        {
            __strong TGMediaAssetsPreheatMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            NSArray *indexPaths = [strongSelf->_collectionView indexPathsForElementsInRect:removedRect];
            [removedIndexPaths addObjectsFromArray:indexPaths];
        } addedHandler:^(CGRect addedRect)
        {
            __strong TGMediaAssetsPreheatMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            NSArray *indexPaths = [strongSelf->_collectionView indexPathsForElementsInRect:addedRect];
            [addedIndexPaths addObjectsFromArray:indexPaths];
        }];
        
        NSArray *assetsToCache = [self _assetsAtIndexPaths:addedIndexPaths];
        NSArray *assetsToInvalidate = [self _assetsAtIndexPaths:removedIndexPaths];
        
        CGSize imageSize = self.imageSize;
        [TGMediaAssetImageSignals startCachingImagesForAssets:assetsToCache imageType:self.imageType size:imageSize];
        [TGMediaAssetImageSignals stopCachingImagesForAssets:assetsToInvalidate imageType:self.imageType size:imageSize];
        
        _previousPreheatRect = preheatRect;
    }
}

- (void)stop
{
    [TGMediaAssetImageSignals stopCachingImagesForAllAssets];
    _previousPreheatRect = CGRectZero;
}

- (NSArray *)_assetsAtIndexPaths:(NSArray *)indexPaths
{
    if (indexPaths.count == 0)
        return nil;
    
    NSInteger assetCount = self.assetCount();
    
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths)
    {
        NSInteger index = indexPath.row;
        
        if (index < assetCount)
            [assets addObject:self.assetAtIndexPath(indexPath)];
    }
    
    return assets;
}

@end


@implementation TGMediaAssetsCollectionViewIncrementalUpdater

+ (void)updateCollectionView:(UICollectionView *)collectionView withChange:(TGMediaAssetFetchResultChange *)__unused change completion:(void (^)(bool incremental))completion
{
    [collectionView reloadData];
    if (completion != nil)
        completion(false);
    
    if (true)
        return;
    
    /*if (!change.hasIncrementalChanges)
    {
        [collectionView reloadData];
        if (completion != nil)
            completion(false);
        return;
    }
    
    NSMutableArray *removedIndexPaths = [[NSMutableArray alloc] init];
    [change.removedIndexes enumerateIndexesUsingBlock:^(NSUInteger index, __unused BOOL *stop)
    {
        [removedIndexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
    }];
    
    NSMutableArray *insertedIndexPaths = [[NSMutableArray alloc] init];
    [change.insertedIndexes enumerateIndexesUsingBlock:^(NSUInteger index, __unused BOOL *stop)
    {
        [insertedIndexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
    }];
    
    NSMutableArray *updatedIndexPaths = [[NSMutableArray alloc] init];
    [change.updatedIndexes enumerateIndexesUsingBlock:^(NSUInteger index, __unused BOOL *stop)
    {
        [updatedIndexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
    }];
    
    [collectionView performBatchUpdates:^
    {
        [collectionView deleteItemsAtIndexPaths:removedIndexPaths];
        [collectionView insertItemsAtIndexPaths:insertedIndexPaths];
    } completion:^(__unused BOOL finished)
    {
        if (updatedIndexPaths.count > 0 || change.hasMoves)
        {
            [collectionView performBatchUpdates:^
            {
                [collectionView reloadItemsAtIndexPaths:updatedIndexPaths];
                
                [change enumerateMovesWithBlock:^(NSUInteger fromIndex, NSUInteger toIndex)
                {
                    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:fromIndex inSection:0];
                    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:toIndex inSection:0];
                    
                    [collectionView moveItemAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
                }];
            } completion:^(__unused BOOL finished)
            {
                if (completion != nil)
                    completion(true);
            }];
        }
        else if (completion != nil)
        {
            completion(true);
        }
    }];*/
}

@end


@implementation TGMediaAssetsSaveToCameraRoll

+ (void)saveImageAtURL:(NSURL *)url
{
    if (![[[LegacyComponentsGlobals provider] accessChecker] checkPhotoAuthorizationStatusForIntent:TGPhotoAccessIntentSave alertDismissCompletion:nil])
        return;
    
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [progressWindow show:true];
    
    [[[[TGMediaAssetsLibrary sharedLibrary] saveAssetWithImageAtUrl:url] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        [[[LegacyComponentsGlobals provider] accessChecker] checkPhotoAuthorizationStatusForIntent:TGPhotoAccessIntentSave alertDismissCompletion:nil];
        [progressWindow dismiss:true];
    } completed:^
    {
        [progressWindow dismissWithSuccess];
    }];
}

+ (void)saveImageWithData:(NSData *)imageData silentlyFail:(bool)silentlyFail completionBlock:(void (^)(bool))completionBlock
{
    TGProgressWindow *progressWindow = nil;
    if (!silentlyFail)
    {
        if (![[[LegacyComponentsGlobals provider] accessChecker] checkPhotoAuthorizationStatusForIntent:TGPhotoAccessIntentSave alertDismissCompletion:nil])
            return;
    
        progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [progressWindow show:true];
    }
    
    [[[[TGMediaAssetsLibrary sharedLibrary] saveAssetWithImageData:imageData] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
     {
         if (!silentlyFail)
         {
             [[[LegacyComponentsGlobals provider] accessChecker] checkPhotoAuthorizationStatusForIntent:TGPhotoAccessIntentSave alertDismissCompletion:nil];
             [progressWindow dismiss:true];
         }
         
         if (completionBlock != nil)
             completionBlock(false);
     } completed:^
     {
         if (!silentlyFail)
             [progressWindow dismissWithSuccess];
         
         if (completionBlock != nil)
             completionBlock(true);
     }];
}

+ (void)saveVideoAtURL:(NSURL *)url
{
    if (![[[LegacyComponentsGlobals provider] accessChecker] checkPhotoAuthorizationStatusForIntent:TGPhotoAccessIntentSave alertDismissCompletion:nil])
        return;
    
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [progressWindow show:true];
    
    [[[[TGMediaAssetsLibrary sharedLibrary] saveAssetWithVideoAtUrl:url] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        [[[LegacyComponentsGlobals provider] accessChecker] checkPhotoAuthorizationStatusForIntent:TGPhotoAccessIntentSave alertDismissCompletion:nil];
        [progressWindow dismiss:true];
    } completed:^
    {
        [progressWindow dismissWithSuccess];
    }];
}

@end


@implementation TGMediaAssetsDateUtils

static bool TGMediaAssetsDateUtilsInitialized = false;

static NSString *value_dateFormat = nil;
static NSString *value_dateYearFormat = nil;

static NSString *value_dateRangeFormat = nil;
static NSString *value_dateRangeYearFormat = nil;
static NSString *value_dateRangeSameMonthFormat = nil;
static NSString *value_dateRangeSameMonthYearFormat = nil;

static void initializeTGMediaAssetsDateUtils()
{
    TGMediaAssetsDateUtilsInitialized = true;
    
    value_dateFormat = [[TGLocalized(@"MediaPicker.MomentsDateFormat") stringByReplacingOccurrencesOfString:@"{month}" withString:@"%2$@"] stringByReplacingOccurrencesOfString:@"{day}" withString:@"%1$d"];
    value_dateYearFormat = [[[TGLocalized(@"MediaPicker.MomentsDateYearFormat") stringByReplacingOccurrencesOfString:@"{month}" withString:@"%2$@"] stringByReplacingOccurrencesOfString:@"{day}" withString:@"%1$d"] stringByReplacingOccurrencesOfString:@"{year}" withString:@"%3$d"];
    value_dateRangeFormat = [[TGLocalized(@"MediaPicker.MomentsDateRangeFormat") stringByReplacingOccurrencesOfString:@"{date1}" withString:@"%1$@"] stringByReplacingOccurrencesOfString:@"{date2}" withString:@"%2$@"];
    value_dateRangeYearFormat = [[[TGLocalized(@"MediaPicker.MomentsDateRangeYearFormat") stringByReplacingOccurrencesOfString:@"{date1}" withString:@"%1$@"] stringByReplacingOccurrencesOfString:@"{date2}" withString:@"%2$@"] stringByReplacingOccurrencesOfString:@"{year}" withString:@"%3$@"];
    value_dateRangeSameMonthFormat = [[[TGLocalized(@"MediaPicker.MomentsDateRangeSameMonthFormat") stringByReplacingOccurrencesOfString:@"{day1}" withString:@"%1$d"] stringByReplacingOccurrencesOfString:@"{day2}" withString:@"%2$d"] stringByReplacingOccurrencesOfString:@"{month}" withString:@"%3$@"];
    value_dateRangeSameMonthYearFormat = [[[[TGLocalized(@"MediaPicker.MomentsDateRangeSameMonthYearFormat") stringByReplacingOccurrencesOfString:@"{date1}" withString:@"%1$d"] stringByReplacingOccurrencesOfString:@"{date2}" withString:@"%2$d"] stringByReplacingOccurrencesOfString:@"{month}" withString:@"%3$@"] stringByReplacingOccurrencesOfString:@"{year}" withString:@"%4$@"];
}

+ (NSString *)formattedDateRangeWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate currentDate:(NSDate *)currentDate shortDate:(bool)shortDate
{
    if (!TGMediaAssetsDateUtilsInitialized)
        initializeTGMediaAssetsDateUtils();
    
    if (endDate == nil)
        endDate = startDate;
    
    time_t t_start = (long)startDate.timeIntervalSince1970;
    struct tm timeinfo_start;
    localtime_r(&t_start, &timeinfo_start);
    
    time_t t_end = (long)endDate.timeIntervalSince1970;
    struct tm timeinfo_end;
    localtime_r(&t_end, &timeinfo_end);
    
    time_t t_now = (long)currentDate.timeIntervalSince1970;
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    int yearOffset = 2000 - 100;
    
    static NSString *(^monthString)(int, bool) = ^(int number, bool shortDate)
    {
        if (shortDate)
            return TGMonthNameShort(number);
        else
            return TGMonthNameFull(number);
    };
    
    if (timeinfo_end.tm_year != timeinfo_now.tm_year)
    {
        if (timeinfo_start.tm_year == timeinfo_end.tm_year)
        {
            if (timeinfo_start.tm_mon == timeinfo_end.tm_mon)
            {
                if (timeinfo_start.tm_yday == timeinfo_end.tm_yday)
                {
                    return [TGStringUtils stringWithLocalizedNumberCharacters:[NSString stringWithFormat:value_dateYearFormat, timeinfo_start.tm_mday, monthString(timeinfo_start.tm_mon, shortDate), timeinfo_start.tm_year + yearOffset]];
                }
                else
                {
                    return [TGStringUtils stringWithLocalizedNumberCharacters:[NSString stringWithFormat:value_dateRangeSameMonthYearFormat, timeinfo_start.tm_mday, timeinfo_end.tm_mday, monthString(timeinfo_start.tm_mon, shortDate), timeinfo_start.tm_year + yearOffset]];
                }
            }
            else
            {
                NSString *startDateString = [NSString stringWithFormat:value_dateFormat, timeinfo_start.tm_mday, monthString(timeinfo_start.tm_mon, shortDate)];
                NSString *endDateString = [NSString stringWithFormat:value_dateFormat, timeinfo_end.tm_mday, monthString(timeinfo_end.tm_mon, shortDate)];
                
                return [TGStringUtils stringWithLocalizedNumberCharacters:[NSString stringWithFormat:value_dateRangeYearFormat, startDateString, endDateString, timeinfo_start.tm_year + yearOffset]];
            }
        }
        else
        {
            NSString *startDateString = [NSString stringWithFormat:value_dateYearFormat, timeinfo_start.tm_mday, monthString(timeinfo_start.tm_mon, shortDate), timeinfo_start.tm_year + yearOffset];
            NSString *endDateString = [NSString stringWithFormat:value_dateYearFormat, timeinfo_end.tm_mday, monthString(timeinfo_end.tm_mon, shortDate), timeinfo_end.tm_year + yearOffset];
            
            return [TGStringUtils stringWithLocalizedNumberCharacters:[NSString stringWithFormat:value_dateRangeFormat, startDateString, endDateString]];
        }
    }
    else
    {
        int dayDiff = timeinfo_start.tm_yday - timeinfo_now.tm_yday;
        
        if (dayDiff < -7)
        {
            if (timeinfo_start.tm_year == timeinfo_end.tm_year)
            {
                if (timeinfo_start.tm_mon == timeinfo_end.tm_mon)
                {
                    if (timeinfo_start.tm_yday == timeinfo_end.tm_yday)
                    {
                        return [TGStringUtils stringWithLocalizedNumberCharacters:[NSString stringWithFormat:value_dateFormat, timeinfo_start.tm_mday, monthString(timeinfo_start.tm_mon, shortDate)]];
                    }
                    else
                    {
                        return [TGStringUtils stringWithLocalizedNumberCharacters:[NSString stringWithFormat:value_dateRangeSameMonthFormat, timeinfo_start.tm_mday, timeinfo_end.tm_mday, monthString(timeinfo_start.tm_mon, shortDate)]];
                    }
                }
                else
                {
                    NSString *startDateString = [NSString stringWithFormat:value_dateFormat, timeinfo_start.tm_mday, monthString(timeinfo_start.tm_mon, shortDate)];
                    NSString *endDateString = [NSString stringWithFormat:value_dateFormat, timeinfo_end.tm_mday, monthString(timeinfo_end.tm_mon, shortDate)];
                    
                    return [TGStringUtils stringWithLocalizedNumberCharacters:[NSString stringWithFormat:value_dateRangeFormat, startDateString, endDateString]];
                }
            }
            else
            {
                NSString *startDateString = [NSString stringWithFormat:value_dateYearFormat, timeinfo_start.tm_mday, monthString(timeinfo_start.tm_mon, shortDate), timeinfo_start.tm_year + yearOffset];
                NSString *endDateString = [NSString stringWithFormat:value_dateYearFormat, timeinfo_end.tm_mday, monthString(timeinfo_end.tm_mon, shortDate), timeinfo_end.tm_year + yearOffset];
                
                return [TGStringUtils stringWithLocalizedNumberCharacters:[NSString stringWithFormat:value_dateRangeFormat, startDateString, endDateString]];
            }
        }
        else
        {
            if (dayDiff == 0)
                return TGLocalized(@"Weekday.Today");
            else if (dayDiff == -1)
                return TGLocalized(@"Weekday.Yesterday");
            if (dayDiff > -7 && dayDiff <= -2)
                return TGWeekdayNameFull(timeinfo_start.tm_wday);
        }
    }
    
    return @"";
}

@end
