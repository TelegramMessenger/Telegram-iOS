@import XCTest;

#import "IDInlineTextStyleResolver.h"

@interface IDInlineTextStyleResolverTests : XCTestCase
@end

@implementation IDInlineTextStyleResolverTests

- (UIFont *)fontWithTraits:(UIFontDescriptorSymbolicTraits)traits {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    UIFontDescriptor *descriptor =
        [font.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    XCTAssertNotNil(descriptor);
    return [UIFont fontWithDescriptor:descriptor size:font.pointSize];
}

- (void)testImportCreatesSemanticMarkersAndMaterializedPresentation {
    UIFont *defaultFont = [UIFont systemFontOfSize:17.0];
    UIFontDescriptor *boldDescriptor =
        [defaultFont.fontDescriptor
            fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    UIFont *boldFont =
        [UIFont fontWithDescriptor:boldDescriptor size:defaultFont.pointSize];
    NSAttributedString *source = [[NSAttributedString alloc]
        initWithString:@"A"
            attributes:@{
                NSFontAttributeName: boldFont,
                NSUnderlineStyleAttributeName:
                    @(NSUnderlineStyleSingle),
            }];
    IDInlineTextStyleResolver *resolver =
        [[IDInlineTextStyleResolver alloc]
            initWithDefaultFont:defaultFont];

    NSAttributedString *imported =
        [resolver importAttributedString:source];
    NSDictionary<NSAttributedStringKey, id> *attributes =
        [imported attributesAtIndex:0 effectiveRange:NULL];

    XCTAssertEqualObjects(attributes[IDInlineTextBoldAttributeName], @YES);
    XCTAssertEqualObjects(attributes[IDInlineTextUnderlineAttributeName], @YES);
    XCTAssertEqual(
        [resolver traitsInAttributes:attributes],
        IDInlineTextTraitBold | IDInlineTextTraitUnderline);
    UIFont *renderedFont = attributes[NSFontAttributeName];
    XCTAssertTrue((renderedFont.fontDescriptor.symbolicTraits &
                   UIFontDescriptorTraitBold) != 0);
    XCTAssertEqual(
        [attributes[NSUnderlineStyleAttributeName] integerValue],
        NSUnderlineStyleSingle);
}

- (void)testImportInfersConcreteTraitsMissingIndividualSemanticMarkers {
    UIFont *defaultFont = [UIFont systemFontOfSize:17.0];
    NSAttributedString *source = [[NSAttributedString alloc]
        initWithString:@"A"
            attributes:@{
                NSFontAttributeName: defaultFont,
                IDInlineTextBoldAttributeName: @YES,
                NSUnderlineStyleAttributeName:
                    @(NSUnderlineStyleSingle),
            }];
    IDInlineTextStyleResolver *resolver =
        [[IDInlineTextStyleResolver alloc]
            initWithDefaultFont:defaultFont];

    NSDictionary<NSAttributedStringKey, id> *attributes =
        [[resolver importAttributedString:source]
            attributesAtIndex:0 effectiveRange:NULL];

    XCTAssertEqual(
        [resolver traitsInAttributes:attributes],
        IDInlineTextTraitBold | IDInlineTextTraitUnderline);
}

- (void)testApplyingBoldPreservesItalicUnderlineColorLinkAndParagraphStyle {
    UIFont *italicFont = [self fontWithTraits:UIFontDescriptorTraitItalic];
    UIColor *color = UIColor.systemPurpleColor;
    NSURL *link = [NSURL URLWithString:@"https://example.com"];
    NSMutableParagraphStyle *paragraphStyle =
        [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.firstLineHeadIndent = 12.0;
    NSDictionary<NSAttributedStringKey, id> *source = @{
        NSFontAttributeName: italicFont,
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        NSForegroundColorAttributeName: color,
        NSLinkAttributeName: link,
        NSParagraphStyleAttributeName: paragraphStyle,
    };
    IDInlineTextStyleResolver *resolver =
        [[IDInlineTextStyleResolver alloc]
            initWithDefaultFont:[UIFont systemFontOfSize:17.0]];
    NSDictionary<NSAttributedStringKey, id> *imported =
        [[resolver importAttributedString:
            [[NSAttributedString alloc] initWithString:@"A"
                                            attributes:source]]
            attributesAtIndex:0 effectiveRange:NULL];

    NSDictionary<NSAttributedStringKey, id> *formatted =
        [resolver attributesByApplyingTraits:
            IDInlineTextTraitBold |
            IDInlineTextTraitItalic |
            IDInlineTextTraitUnderline
                                  toAttributes:imported];

    XCTAssertEqualObjects(formatted[NSForegroundColorAttributeName], color);
    XCTAssertEqualObjects(formatted[NSLinkAttributeName], link);
    XCTAssertEqualObjects(formatted[NSParagraphStyleAttributeName],
                          paragraphStyle);
    XCTAssertEqual(
        [resolver traitsInAttributes:formatted],
        IDInlineTextTraitBold |
        IDInlineTextTraitItalic |
        IDInlineTextTraitUnderline);
}

- (void)testRemovingBoldRestoresTheBaseFontAndKeepsOtherTraits {
    UIFont *boldItalicFont =
        [self fontWithTraits:UIFontDescriptorTraitBold |
                             UIFontDescriptorTraitItalic];
    IDInlineTextStyleResolver *resolver =
        [[IDInlineTextStyleResolver alloc]
            initWithDefaultFont:[UIFont systemFontOfSize:17.0]];
    NSDictionary<NSAttributedStringKey, id> *imported =
        [[resolver importAttributedString:
            [[NSAttributedString alloc]
                initWithString:@"A"
                    attributes:@{
                        NSFontAttributeName: boldItalicFont,
                        NSUnderlineStyleAttributeName:
                            @(NSUnderlineStyleSingle),
                    }]]
            attributesAtIndex:0 effectiveRange:NULL];

    NSDictionary<NSAttributedStringKey, id> *formatted =
        [resolver attributesByApplyingTraits:
            IDInlineTextTraitItalic | IDInlineTextTraitUnderline
                                  toAttributes:imported];
    UIFont *font = formatted[NSFontAttributeName];

    XCTAssertEqual(font.fontDescriptor.symbolicTraits &
                       (UIFontDescriptorTraitBold |
                        UIFontDescriptorTraitItalic),
                   UIFontDescriptorTraitItalic);
    XCTAssertEqual(
        [resolver traitsInAttributes:formatted],
        IDInlineTextTraitItalic | IDInlineTextTraitUnderline);
}

- (void)testAllFourTraitsComposeAndRoundTrip {
    IDInlineTextStyleResolver *resolver =
        [[IDInlineTextStyleResolver alloc]
            initWithDefaultFont:[UIFont systemFontOfSize:17.0]];
    IDInlineTextTraits allTraits =
        IDInlineTextTraitBold |
        IDInlineTextTraitItalic |
        IDInlineTextTraitUnderline |
        IDInlineTextTraitStrikethrough;
    NSDictionary<NSAttributedStringKey, id> *formatted =
        [resolver attributesByApplyingTraits:allTraits
                                  toAttributes:@{}];
    NSAttributedString *roundTripped =
        [resolver importAttributedString:
            [[NSAttributedString alloc] initWithString:@"A"
                                            attributes:formatted]];
    NSDictionary<NSAttributedStringKey, id> *attributes =
        [roundTripped attributesAtIndex:0 effectiveRange:NULL];

    XCTAssertEqual([resolver traitsInAttributes:attributes], allTraits);
    XCTAssertEqual(
        [attributes[NSUnderlineStyleAttributeName] integerValue],
        NSUnderlineStyleSingle);
    XCTAssertEqual(
        [attributes[NSStrikethroughStyleAttributeName] integerValue],
        NSUnderlineStyleSingle);
}

- (void)testSystemPresentationChangeDoesNotChangeExistingSemanticIntent {
    IDInlineTextStyleResolver *resolver =
        [[IDInlineTextStyleResolver alloc]
            initWithDefaultFont:[UIFont systemFontOfSize:17.0]];
    NSDictionary<NSAttributedStringKey, id> *imported =
        [[resolver importAttributedString:
            [[NSAttributedString alloc]
                initWithString:@"A"
                    attributes:@{
                        NSFontAttributeName:
                            [self fontWithTraits:UIFontDescriptorTraitBold],
                    }]]
            attributesAtIndex:0 effectiveRange:NULL];
    NSMutableDictionary<NSAttributedStringKey, id> *presentationChanged =
        imported.mutableCopy;
    presentationChanged[NSFontAttributeName] =
        [self fontWithTraits:UIFontDescriptorTraitBold |
                             UIFontDescriptorTraitItalic];

    NSDictionary<NSAttributedStringKey, id> *reimported =
        [[resolver importAttributedString:
            [[NSAttributedString alloc]
                initWithString:@"A"
                    attributes:presentationChanged]]
            attributesAtIndex:0 effectiveRange:NULL];

    XCTAssertEqual([resolver traitsInAttributes:reimported],
                   IDInlineTextTraitBold);
}

- (void)testEmptyAttributedStringImportsWithoutSyntheticCharacters {
    IDInlineTextStyleResolver *resolver =
        [[IDInlineTextStyleResolver alloc]
            initWithDefaultFont:[UIFont systemFontOfSize:17.0]];

    NSAttributedString *imported =
        [resolver importAttributedString:
            [[NSAttributedString alloc] initWithString:@""]];

    XCTAssertEqual(imported.length, 0);
    XCTAssertEqualObjects(imported.string, @"");
}

@end
