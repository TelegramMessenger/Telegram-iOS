#import "TGMediaAttachment.h"

#import <LegacyComponents/TGWebDocument.h>

#define TGInvoiceMediaAttachmentType ((int)0x17af081f)

@class TGWebPageMediaAttachment;

@interface TGInvoiceMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly) TGWebDocument *photo;
@property (nonatomic, strong, readonly) NSString *currency;
@property (nonatomic, readonly) int64_t totalAmount;
@property (nonatomic, readonly) int32_t receiptMessageId;
@property (nonatomic, strong, readonly) NSString *invoiceStartParam;
@property (nonatomic, readonly) bool shippingAddressRequested;
@property (nonatomic, readonly) bool isTest;

- (instancetype)initWithTitle:(NSString *)title text:(NSString *)text photo:(TGWebDocument *)photo currency:(NSString *)currency totalAmount:(int64_t)totalAmount receiptMessageId:(int32_t)receiptMessageId invoiceStartParam:(NSString *)invoiceStartParam shippingAddressRequested:(bool)shippingAddressRequested isTest:(bool)isTest;

- (TGWebPageMediaAttachment *)webpage;

@end
