#import "TGInvoiceMediaAttachment.h"

#import "LegacyComponentsInternal.h"

#import "NSInputStream+TL.h"

#import "TGWebPageMediaAttachment.h"

@implementation TGInvoiceMediaAttachment

- (instancetype)initWithTitle:(NSString *)title text:(NSString *)text photo:(TGWebDocument *)photo currency:(NSString *)currency totalAmount:(int64_t)totalAmount receiptMessageId:(int32_t)receiptMessageId invoiceStartParam:(NSString *)invoiceStartParam shippingAddressRequested:(bool)shippingAddressRequested isTest:(bool)isTest {
    self = [super init];
    if (self != nil) {
        self.type = TGInvoiceMediaAttachmentType;
        
        _title = title;
        _text = text;
        _photo = photo;
        _currency = currency;
        _totalAmount = totalAmount;
        _receiptMessageId = receiptMessageId;
        _invoiceStartParam = invoiceStartParam;
        _shippingAddressRequested = shippingAddressRequested;
        _isTest = isTest;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithTitle:[aDecoder decodeObjectForKey:@"title"] text:[aDecoder decodeObjectForKey:@"text"] photo:[aDecoder decodeObjectForKey:@"photo"] currency:[aDecoder decodeObjectForKey:@"currency"] totalAmount:[aDecoder decodeInt64ForKey:@"totalAmount"] receiptMessageId:[aDecoder decodeInt32ForKey:@"receiptMessageId"] invoiceStartParam:[aDecoder decodeObjectForKey:@"invoiceStartParam"] shippingAddressRequested:[aDecoder decodeBoolForKey:@"shippingAddressRequested"] isTest:[aDecoder decodeBoolForKey:@"isTest"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_title forKey:@"title"];
    [aCoder encodeObject:_text forKey:@"text"];
    [aCoder encodeObject:_photo forKey:@"photo"];
    [aCoder encodeObject:_currency forKey:@"currency"];
    [aCoder encodeInt64:_totalAmount forKey:@"totalAmount"];
    [aCoder encodeInt32:_receiptMessageId forKey:@"receiptMessageId"];
    [aCoder encodeObject:_invoiceStartParam forKey:@"invoiceStartParam"];
    [aCoder encodeBool:_shippingAddressRequested forKey:@"shippingAddressRequested"];
    [aCoder encodeBool:_isTest forKey:@"isTest"];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TGInvoiceMediaAttachment class]]) {
        return false;
    }
    TGInvoiceMediaAttachment *other = (TGInvoiceMediaAttachment *)object;
    if (!TGStringCompare(_title, other->_title)) {
        return false;
    }
    if (!TGStringCompare(_text, other->_text)) {
        return false;
    }
    if (!TGObjectCompare(_photo, other->_photo)) {
        return false;
    }
    if (!TGStringCompare(_currency, other->_currency)) {
        return false;
    }
    if (_totalAmount != other->_totalAmount) {
        return false;
    }
    if (_receiptMessageId != other->_receiptMessageId) {
        return false;
    }
    if (!TGStringCompare(_invoiceStartParam, other->_invoiceStartParam)) {
        return false;
    }
    if (_shippingAddressRequested != other->_shippingAddressRequested) {
        return false;
    }
    if (_isTest != other->_isTest) {
        return false;
    }
    return true;
}

- (void)serialize:(NSMutableData *)data
{
    NSData *serializedData = [NSKeyedArchiver archivedDataWithRootObject:self];
    int32_t length = (int32_t)serializedData.length;
    [data appendBytes:&length length:4];
    [data appendData:serializedData];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int32_t length = [is readInt32];
    NSData *data = [is readData:length];
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}


- (TGWebPageMediaAttachment *)webpage {
    TGWebPageMediaAttachment *webPage = [[TGWebPageMediaAttachment alloc] init];
    webPage.siteName = self.title;
    webPage.pageDescription = _text;
    
    if (_photo != nil) {
        TGImageInfo *imageInfo = [[TGImageInfo alloc] init];
        for (id attribute in _photo.attributes) {
            if ([attribute isKindOfClass:[TGDocumentAttributeImageSize class]]) {
                CGSize imageSize = ((TGDocumentAttributeImageSize *)attribute).size;
                if (imageSize.width < 1.0f || imageSize.height < 1.0f) {
                    imageSize = CGSizeMake(480.0f, 480.0f);
                }
                [imageInfo addImageWithSize:imageSize url:[[_photo reference] toString]];
                TGImageMediaAttachment *imageMedia = [[TGImageMediaAttachment alloc] init];
                imageMedia.imageInfo = imageInfo;
                webPage.photo = imageMedia;
                break;
            }
        }
    }
    webPage.pageType = @"invoice";
    return webPage;
}

@end
