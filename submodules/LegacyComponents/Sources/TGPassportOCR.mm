#import "TGPassportOCR.h"

#import "LegacyComponentsInternal.h"
#import <Vision/Vision.h>

#import "TGPassportMRZ.h"
#import "ocr.h"

@implementation TGPassportOCR

+ (SSignal *)recognizeDataInImage:(UIImage *)image shouldBeDriversLicense:(bool)shouldBeDriversLicense
{
    if (iosMajorVersion() < 11)
        return [self recognizeMRZInImage:image];
    
    SSignal *initial = shouldBeDriversLicense ? [self recognizeBarcodeInImage:image] : [self recognizeMRZInImage:image];
    SSignal *fallback = shouldBeDriversLicense ? [self recognizeMRZInImage:image] : [self recognizeBarcodeInImage:image];
    
    return [initial mapToSignal:^SSignal *(id value)
    {
        if (value != nil)
            return [SSignal single:value];
        return fallback;
    }];
}

+ (SSignal *)recognizeMRZInImage:(UIImage *)image
{
    return [[SSignal defer:^SSignal *
    {
        CGRect boundingRect;
        NSString *string = recognizeMRZ(image, &boundingRect);
        
        NSArray *lines = [string componentsSeparatedByString:@"\n"];
        TGPassportMRZ *mrz = [TGPassportMRZ parseLines:lines];
        
        return [SSignal single:mrz];
    }] startOn:[SQueue concurrentDefaultQueue]];
}

+ (SSignal *)recognizeBarcodeInImage:(UIImage *)image
{
    if (@available(iOS 11.0, *)) {
        return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
            VNDetectBarcodesRequest *barcodeRequest = [[VNDetectBarcodesRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error)
            {
                TGPassportMRZ *mrz = nil;
                NSArray *results = request.results;
                for (VNBarcodeObservation *barcode in results)
                {
                    if (![barcode isKindOfClass:[VNBarcodeObservation class]])
                        continue;

                    if (barcode.symbology != VNBarcodeSymbologyPDF417)
                        continue;

                    NSString *payload = barcode.payloadStringValue;
                    mrz = [TGPassportMRZ parseBarcodePayload:payload];
                }

                [subscriber putNext:mrz];
                [subscriber putCompletion];
            }];

            NSError *error;
            VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage options:@{}];
            [handler performRequests:@[barcodeRequest] error:&error];

            return nil;
        }] startOn:[SQueue concurrentDefaultQueue]];
    } else {
        return [SSignal complete];
    }
}

@end
