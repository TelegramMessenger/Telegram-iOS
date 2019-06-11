// TTTAttributedLabel.h
//
// Copyright (c) 2011 Mattt Thompson (http://mattt.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

//! Project version number for BITAttributedLabel.
FOUNDATION_EXPORT double BITAttributedLabelVersionNumber;

//! Project version string for BITAttributedLabel.
FOUNDATION_EXPORT const unsigned char BITAttributedLabelVersionString[];

@class BITAttributedLabelLink;

/**
 Vertical alignment for text in a label whose bounds are larger than its text bounds
 */
typedef NS_ENUM(NSInteger, BITAttributedLabelVerticalAlignment) {
  BITAttributedLabelVerticalAlignmentCenter   = 0,
  BITAttributedLabelVerticalAlignmentTop      = 1,
  BITAttributedLabelVerticalAlignmentBottom   = 2,
};

/**
 Determines whether the text to which this attribute applies has a strikeout drawn through itself.
 */
extern NSString * const kBITStrikeOutAttributeName;

/**
 The background fill color. Value must be a `CGColorRef`. Default value is `nil` (no fill).
 */
extern NSString * const kBITBackgroundFillColorAttributeName;

/**
 The padding for the background fill. Value must be a `UIEdgeInsets`. Default value is `UIEdgeInsetsZero` (no padding).
 */
extern NSString * const kBITBackgroundFillPaddingAttributeName;

/**
 The background stroke color. Value must be a `CGColorRef`. Default value is `nil` (no stroke).
 */
extern NSString * const kBITBackgroundStrokeColorAttributeName;

/**
 The background stroke line width. Value must be an `NSNumber`. Default value is `1.0f`.
 */
extern NSString * const kBITBackgroundLineWidthAttributeName;

/**
 The background corner radius. Value must be an `NSNumber`. Default value is `5.0f`.
 */
extern NSString * const kBITBackgroundCornerRadiusAttributeName;

@protocol BITAttributedLabelDelegate;

// Override UILabel @property to accept both NSString and NSAttributedString
@protocol BITAttributedLabel <NSObject>
@property (nonatomic, copy) IBInspectable id text;
@end

IB_DESIGNABLE

/**
 `BITAttributedLabel` is a drop-in replacement for `UILabel` that supports `NSAttributedString`, as well as automatically-detected and manually-added links to URLs, addresses, phone numbers, and dates.

 ## Differences Between `BITAttributedLabel` and `UILabel`

 For the most part, `BITAttributedLabel` behaves just like `UILabel`. The following are notable exceptions, in which `BITAttributedLabel` may act differently:

 - `text` - This property now takes an `id` type argument, which can either be a kind of `NSString` or `NSAttributedString` (mutable or immutable in both cases)
 - `attributedText` - Do not set this property directly. Instead, pass an `NSAttributedString` to `text`.
 - `lineBreakMode` - This property displays only the first line when the value is `UILineBreakModeHeadTruncation`, `UILineBreakModeTailTruncation`, or `UILineBreakModeMiddleTruncation`
 - `adjustsFontsizeToFitWidth` - Supported in iOS 5 and greater, this property is effective for any value of `numberOfLines` greater than zero. In iOS 4, setting `numberOfLines` to a value greater than 1 with `adjustsFontSizeToFitWidth` set to `YES` may cause `sizeToFit` to execute indefinitely.
 - `baselineAdjustment` - This property has no affect.
 - `textAlignment` - This property does not support justified alignment.
 - `NSTextAttachment` - This string attribute is not supported.

 Any properties affecting text or paragraph styling, such as `firstLineIndent` will only apply when text is set with an `NSString`. If the text is set with an `NSAttributedString`, these properties will not apply.

 ### NSCoding

 `BITAttributedLabel`, like `UILabel`, conforms to `NSCoding`. However, if the build target is set to less than iOS 6.0, `linkAttributes` and `activeLinkAttributes` will not be encoded or decoded. This is due to an runtime exception thrown when attempting to copy non-object CoreText values in dictionaries.

 @warning Any properties changed on the label after setting the text will not be reflected until a subsequent call to `setText:` or `setText:afterInheritingLabelAttributesAndConfiguringWithBlock:`. This is to say, order of operations matters in this case. For example, if the label text color is originally black when the text is set, changing the text color to red will have no effect on the display of the label until the text is set once again.

 @bug Setting `attributedText` directly is not recommended, as it may cause a crash when attempting to access any links previously set. Instead, call `setText:`, passing an `NSAttributedString`.
 */
@interface BITAttributedLabel : UILabel <BITAttributedLabel, UIGestureRecognizerDelegate>

/**
 * The designated initializers are @c initWithFrame: and @c initWithCoder:.
 * init will not properly initialize many required properties and other configuration.
 */
- (instancetype) init NS_UNAVAILABLE;

///-----------------------------
/// @name Accessing the Delegate
///-----------------------------

/**
 The receiver's delegate.

 @discussion A `BITAttributedLabel` delegate responds to messages sent by tapping on links in the label. You can use the delegate to respond to links referencing a URL, address, phone number, date, or date with a specified time zone and duration.
 */
@property (nonatomic, unsafe_unretained) IBOutlet id <BITAttributedLabelDelegate> delegate;

///--------------------------------------------
/// @name Detecting, Accessing, & Styling Links
///--------------------------------------------

/**
 A bitmask of `NSTextCheckingType` which are used to automatically detect links in the label text.

 @warning You must specify `enabledTextCheckingTypes` before setting the `text`, with either `setText:` or `setText:afterInheritingLabelAttributesAndConfiguringWithBlock:`.
 */
@property (nonatomic, assign) NSTextCheckingTypes enabledTextCheckingTypes;

/**
 An array of `NSTextCheckingResult` objects for links detected or manually added to the label text.
 */
@property (readonly, nonatomic, strong) NSArray *links;

/**
 A dictionary containing the default `NSAttributedString` attributes to be applied to links detected or manually added to the label text. The default link style is blue and underlined.

 @warning You must specify `linkAttributes` before setting autodecting or manually-adding links for these attributes to be applied.
 */
@property (nonatomic, strong) NSDictionary *linkAttributes;

/**
 A dictionary containing the default `NSAttributedString` attributes to be applied to links when they are in the active state. If `nil` or an empty `NSDictionary`, active links will not be styled. The default active link style is red and underlined.
 */
@property (nonatomic, strong) NSDictionary *activeLinkAttributes;

/**
 A dictionary containing the default `NSAttributedString` attributes to be applied to links when they are in the inactive state, which is triggered by a change in `tintColor` in iOS 7 and later. If `nil` or an empty `NSDictionary`, inactive links will not be styled. The default inactive link style is gray and unadorned.
 */
@property (nonatomic, strong) NSDictionary *inactiveLinkAttributes;

/**
 The edge inset for the background of a link. The default value is `{0, -1, 0, -1}`.
 */
@property (nonatomic, assign) UIEdgeInsets linkBackgroundEdgeInset;

/**
 Indicates if links will be detected within an extended area around the touch
 to emulate the link detection behaviour of UIWebView.
 Default value is NO. Enabling this may adversely impact performance.
 */
@property (nonatomic, assign) BOOL extendsLinkTouchArea;

///---------------------------------------
/// @name Acccessing Text Style Attributes
///---------------------------------------

/**
 The shadow blur radius for the label. A value of 0 indicates no blur, while larger values produce correspondingly larger blurring. This value must not be negative. The default value is 0.
 */
@property (nonatomic, assign) IBInspectable CGFloat shadowRadius;

/**
 The shadow blur radius for the label when the label's `highlighted` property is `YES`. A value of 0 indicates no blur, while larger values produce correspondingly larger blurring. This value must not be negative. The default value is 0.
 */
@property (nonatomic, assign) IBInspectable CGFloat highlightedShadowRadius;
/**
 The shadow offset for the label when the label's `highlighted` property is `YES`. A size of {0, 0} indicates no offset, with positive values extending down and to the right. The default size is {0, 0}.
 */
@property (nonatomic, assign) IBInspectable CGSize highlightedShadowOffset;
/**
 The shadow color for the label when the label's `highlighted` property is `YES`. The default value is `nil` (no shadow color).
 */
@property (nonatomic, strong) IBInspectable UIColor *highlightedShadowColor;

/**
 The amount to kern the next character. Default is standard kerning. If this attribute is set to 0.0, no kerning is done at all.
 */
@property (nonatomic, assign) IBInspectable CGFloat kern;

///--------------------------------------------
/// @name Acccessing Paragraph Style Attributes
///--------------------------------------------

/**
 The distance, in points, from the leading margin of a frame to the beginning of the
 paragraph's first line. This value is always nonnegative, and is 0.0 by default.
 This applies to the full text, rather than any specific paragraph metrics.
 */
@property (nonatomic, assign) IBInspectable CGFloat firstLineIndent;

/**
 The space in points added between lines within the paragraph. This value is always nonnegative and is 0.0 by default.
 */
@property (nonatomic, assign) IBInspectable CGFloat lineSpacing;

/**
 The minimum line height within the paragraph. If the value is 0.0, the minimum line height is set to the line height of the `font`. 0.0 by default.
 */
@property (nonatomic, assign) IBInspectable CGFloat minimumLineHeight;

/**
 The maximum line height within the paragraph. If the value is 0.0, the maximum line height is set to the line height of the `font`. 0.0 by default.
 */
@property (nonatomic, assign) IBInspectable CGFloat maximumLineHeight;

/**
 The line height multiple. This value is 1.0 by default.
 */
@property (nonatomic, assign) IBInspectable CGFloat lineHeightMultiple;

/**
 The distance, in points, from the margin to the text container. This value is `UIEdgeInsetsZero` by default.
 sizeThatFits: will have its returned size increased by these margins.
 drawTextInRect: will inset all drawn text by these margins.
 */
@property (nonatomic, assign) IBInspectable UIEdgeInsets textInsets;

/**
 The vertical text alignment for the label, for when the frame size is greater than the text rect size. The vertical alignment is `BITAttributedLabelVerticalAlignmentCenter` by default.
 */
@property (nonatomic, assign) BITAttributedLabelVerticalAlignment verticalAlignment;

///--------------------------------------------
/// @name Accessing Truncation Token Appearance
///--------------------------------------------

/**
 The attributed string to apply to the truncation token at the end of a truncated line.
 */
@property (nonatomic, strong) IBInspectable NSAttributedString *attributedTruncationToken;

///--------------------------
/// @name Long press gestures
///--------------------------

/**
 *  The long-press gesture recognizer used internally by the label.
 */
@property (nonatomic, strong, readonly) UILongPressGestureRecognizer *longPressGestureRecognizer;

///--------------------------------------------
/// @name Calculating Size of Attributed String
///--------------------------------------------

/**
 Calculate and return the size that best fits an attributed string, given the specified constraints on size and number of lines.

 @param attributedString The attributed string.
 @param size The maximum dimensions used to calculate size.
 @param numberOfLines The maximum number of lines in the text to draw, if the constraining size cannot accomodate the full attributed string.

 @return The size that fits the attributed string within the specified constraints.
 */
+ (CGSize)sizeThatFitsAttributedString:(NSAttributedString *)attributedString
                       withConstraints:(CGSize)size
                limitedToNumberOfLines:(NSUInteger)numberOfLines;

///----------------------------------
/// @name Setting the Text Attributes
///----------------------------------

/**
 Sets the text displayed by the label.

 @param text An `NSString` or `NSAttributedString` object to be displayed by the label. If the specified text is an `NSString`, the label will display the text like a `UILabel`, inheriting the text styles of the label. If the specified text is an `NSAttributedString`, the label text styles will be overridden by the styles specified in the attributed string.

 @discussion This method overrides `UILabel -setText:` to accept both `NSString` and `NSAttributedString` objects. This string is `nil` by default.
 */
- (void)setText:(id)text;

/**
 Sets the text displayed by the label, after configuring an attributed string containing the text attributes inherited from the label in a block.

 @param text An `NSString` or `NSAttributedString` object to be displayed by the label.
 @param block A block object that returns an `NSMutableAttributedString` object and takes a single argument, which is an `NSMutableAttributedString` object with the text from the first parameter, and the text attributes inherited from the label text styles. For example, if you specified the `font` of the label to be `[UIFont boldSystemFontOfSize:14]` and `textColor` to be `[UIColor redColor]`, the `NSAttributedString` argument of the block would be contain the `NSAttributedString` attribute equivalents of those properties. In this block, you can set further attributes on particular ranges.

 @discussion This string is `nil` by default.
 */
- (void)setText:(id)text
afterInheritingLabelAttributesAndConfiguringWithBlock:(NSMutableAttributedString *(^)(NSMutableAttributedString *mutableAttributedString))block;

///------------------------------------
/// @name Accessing the Text Attributes
///------------------------------------

/**
 A copy of the label's current attributedText. This returns `nil` if an attributed string has never been set on the label.

 @warning Do not set this property directly. Instead, set @c text to an @c NSAttributedString.
 */
@property (readwrite, nonatomic, copy) NSAttributedString *attributedText;

///-------------------
/// @name Adding Links
///-------------------

/**
 Adds a link. You can customize an individual link's appearance and accessibility value by creating your own @c BITAttributedLabelLink and passing it to this method. The other methods for adding links will use the label's default attributes.

 @warning Modifying the link's attribute dictionaries must be done before calling this method.

 @param link A @c BITAttributedLabelLink object.
 */
- (void)addLink:(BITAttributedLabelLink *)link;

/**
 Adds a link to an @c NSTextCheckingResult.

 @param result An @c NSTextCheckingResult representing the link's location and type.

 @return The newly added link object.
 */
- (BITAttributedLabelLink *)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result;

/**
 Adds a link to an @c NSTextCheckingResult.

 @param result An @c NSTextCheckingResult representing the link's location and type.
 @param attributes The attributes to be added to the text in the range of the specified link. If set, the label's @c activeAttributes and @c inactiveAttributes will be applied to the link. If `nil`, no attributes are added to the link.

 @return The newly added link object.
 */
- (BITAttributedLabelLink *)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result
                                               attributes:(NSDictionary *)attributes;

/**
 Adds a link to a URL for a specified range in the label text.

 @param url The url to be linked to
 @param range The range in the label text of the link. The range must not exceed the bounds of the receiver.

 @return The newly added link object.
 */
- (BITAttributedLabelLink *)addLinkToURL:(NSURL *)url
                               withRange:(NSRange)range;

/**
 Adds a link to an address for a specified range in the label text.

 @param addressComponents A dictionary of address components for the address to be linked to
 @param range The range in the label text of the link. The range must not exceed the bounds of the receiver.

 @discussion The address component dictionary keys are described in `NSTextCheckingResult`'s "Keys for Address Components."

 @return The newly added link object.
 */
- (BITAttributedLabelLink *)addLinkToAddress:(NSDictionary *)addressComponents
                                   withRange:(NSRange)range;

/**
 Adds a link to a phone number for a specified range in the label text.

 @param phoneNumber The phone number to be linked to.
 @param range The range in the label text of the link. The range must not exceed the bounds of the receiver.

 @return The newly added link object.
 */
- (BITAttributedLabelLink *)addLinkToPhoneNumber:(NSString *)phoneNumber
                                       withRange:(NSRange)range;

/**
 Adds a link to a date for a specified range in the label text.

 @param date The date to be linked to.
 @param range The range in the label text of the link. The range must not exceed the bounds of the receiver.

 @return The newly added link object.
 */
- (BITAttributedLabelLink *)addLinkToDate:(NSDate *)date
                                withRange:(NSRange)range;

/**
 Adds a link to a date with a particular time zone and duration for a specified range in the label text.

 @param date The date to be linked to.
 @param timeZone The time zone of the specified date.
 @param duration The duration, in seconds from the specified date.
 @param range The range in the label text of the link. The range must not exceed the bounds of the receiver.

 @return The newly added link object.
 */
- (BITAttributedLabelLink *)addLinkToDate:(NSDate *)date
                                 timeZone:(NSTimeZone *)timeZone
                                 duration:(NSTimeInterval)duration
                                withRange:(NSRange)range;

/**
 Adds a link to transit information for a specified range in the label text.

 @param components A dictionary containing the transit components. The currently supported keys are `NSTextCheckingAirlineKey` and `NSTextCheckingFlightKey`.
 @param range The range in the label text of the link. The range must not exceed the bounds of the receiver.

 @return The newly added link object.
 */
- (BITAttributedLabelLink *)addLinkToTransitInformation:(NSDictionary *)components
                                              withRange:(NSRange)range;

/**
 Returns whether an @c NSTextCheckingResult is found at the give point.

 @discussion This can be used together with @c UITapGestureRecognizer to tap interactions with overlapping views.

 @param point The point inside the label.
 */
- (BOOL)containslinkAtPoint:(CGPoint)point;

/**
 Returns the @c BITAttributedLabelLink at the give point if it exists.

 @discussion This can be used together with @c UIViewControllerPreviewingDelegate to peek into links.

 @param point The point inside the label.
 */
- (BITAttributedLabelLink *)linkAtPoint:(CGPoint)point;

@end

/**
 The `BITAttributedLabelDelegate` protocol defines the messages sent to an attributed label delegate when links are tapped. All of the methods of this protocol are optional.
 */
@protocol BITAttributedLabelDelegate <NSObject>

///-----------------------------------
/// @name Responding to Link Selection
///-----------------------------------
@optional

/**
 Tells the delegate that the user did select a link to a URL.

 @param label The label whose link was selected.
 @param url The URL for the selected link.
 */
- (void)attributedLabel:(BITAttributedLabel *)label
   didSelectLinkWithURL:(NSURL *)url;

/**
 Tells the delegate that the user did select a link to an address.

 @param label The label whose link was selected.
 @param addressComponents The components of the address for the selected link.
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didSelectLinkWithAddress:(NSDictionary *)addressComponents;

/**
 Tells the delegate that the user did select a link to a phone number.

 @param label The label whose link was selected.
 @param phoneNumber The phone number for the selected link.
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didSelectLinkWithPhoneNumber:(NSString *)phoneNumber;

/**
 Tells the delegate that the user did select a link to a date.

 @param label The label whose link was selected.
 @param date The datefor the selected link.
 */
- (void)attributedLabel:(BITAttributedLabel *)label
  didSelectLinkWithDate:(NSDate *)date;

/**
 Tells the delegate that the user did select a link to a date with a time zone and duration.

 @param label The label whose link was selected.
 @param date The date for the selected link.
 @param timeZone The time zone of the date for the selected link.
 @param duration The duration, in seconds from the date for the selected link.
 */
- (void)attributedLabel:(BITAttributedLabel *)label
  didSelectLinkWithDate:(NSDate *)date
               timeZone:(NSTimeZone *)timeZone
               duration:(NSTimeInterval)duration;

/**
 Tells the delegate that the user did select a link to transit information

 @param label The label whose link was selected.
 @param components A dictionary containing the transit components. The currently supported keys are `NSTextCheckingAirlineKey` and `NSTextCheckingFlightKey`.
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didSelectLinkWithTransitInformation:(NSDictionary *)components;

/**
 Tells the delegate that the user did select a link to a text checking result.

 @discussion This method is called if no other delegate method was called, which can occur by either now implementing the method in `BITAttributedLabelDelegate` corresponding to a particular link, or the link was added by passing an instance of a custom `NSTextCheckingResult` subclass into `-addLinkWithTextCheckingResult:`.

 @param label The label whose link was selected.
 @param result The custom text checking result.
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didSelectLinkWithTextCheckingResult:(NSTextCheckingResult *)result;

///---------------------------------
/// @name Responding to Long Presses
///---------------------------------

/**
 *  Long-press delegate methods include the CGPoint tapped within the label's coordinate space.
 *  This may be useful on iPad to present a popover from a specific origin point.
 */

/**
 Tells the delegate that the user long-pressed a link to a URL.

 @param label The label whose link was long pressed.
 @param url The URL for the link.
 @param point the point pressed, in the label's coordinate space
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didLongPressLinkWithURL:(NSURL *)url
                atPoint:(CGPoint)point;

/**
 Tells the delegate that the user long-pressed a link to an address.

 @param label The label whose link was long pressed.
 @param addressComponents The components of the address for the link.
 @param point the point pressed, in the label's coordinate space
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didLongPressLinkWithAddress:(NSDictionary *)addressComponents
                atPoint:(CGPoint)point;

/**
 Tells the delegate that the user long-pressed a link to a phone number.

 @param label The label whose link was long pressed.
 @param phoneNumber The phone number for the link.
 @param point the point pressed, in the label's coordinate space
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didLongPressLinkWithPhoneNumber:(NSString *)phoneNumber
                atPoint:(CGPoint)point;


/**
 Tells the delegate that the user long-pressed a link to a date.

 @param label The label whose link was long pressed.
 @param date The date for the selected link.
 @param point the point pressed, in the label's coordinate space
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didLongPressLinkWithDate:(NSDate *)date
                atPoint:(CGPoint)point;


/**
 Tells the delegate that the user long-pressed a link to a date with a time zone and duration.

 @param label The label whose link was long pressed.
 @param date The date for the link.
 @param timeZone The time zone of the date for the link.
 @param duration The duration, in seconds from the date for the link.
 @param point the point pressed, in the label's coordinate space
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didLongPressLinkWithDate:(NSDate *)date
               timeZone:(NSTimeZone *)timeZone
               duration:(NSTimeInterval)duration
                atPoint:(CGPoint)point;


/**
 Tells the delegate that the user long-pressed a link to transit information.

 @param label The label whose link was long pressed.
 @param components A dictionary containing the transit components. The currently supported keys are `NSTextCheckingAirlineKey` and `NSTextCheckingFlightKey`.
 @param point the point pressed, in the label's coordinate space
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didLongPressLinkWithTransitInformation:(NSDictionary *)components
                atPoint:(CGPoint)point;

/**
 Tells the delegate that the user long-pressed a link to a text checking result.

 @discussion Similar to `-attributedLabel:didSelectLinkWithTextCheckingResult:`, this method is called if a link is long pressed and the delegate does not implement the method corresponding to this type of link.

 @param label The label whose link was long pressed.
 @param result The custom text checking result.
 @param point the point pressed, in the label's coordinate space
 */
- (void)attributedLabel:(BITAttributedLabel *)label
didLongPressLinkWithTextCheckingResult:(NSTextCheckingResult *)result
                atPoint:(CGPoint)point;

@end

@interface BITAttributedLabelLink : NSObject <NSCoding>

typedef void (^BITAttributedLabelLinkBlock) (BITAttributedLabel *, BITAttributedLabelLink *);

/**
 An `NSTextCheckingResult` representing the link's location and type.
 */
@property (readonly, nonatomic, strong) NSTextCheckingResult *result;

/**
 A dictionary containing the @c NSAttributedString attributes to be applied to the link.
 */
@property (readonly, nonatomic, copy) NSDictionary *attributes;

/**
 A dictionary containing the @c NSAttributedString attributes to be applied to the link when it is in the active state.
 */
@property (readonly, nonatomic, copy) NSDictionary *activeAttributes;

/**
 A dictionary containing the @c NSAttributedString attributes to be applied to the link when it is in the inactive state, which is triggered by a change in `tintColor` in iOS 7 and later.
 */
@property (readonly, nonatomic, copy) NSDictionary *inactiveAttributes;

/**
 Additional information about a link for VoiceOver users. Has default values if the link's @c result is @c NSTextCheckingTypeLink, @c NSTextCheckingTypePhoneNumber, or @c NSTextCheckingTypeDate.
 */
@property (nonatomic, copy) NSString *accessibilityValue;

/**
 A block called when this link is tapped.
 If non-nil, tapping on this link will call this block instead of the
 @c BITAttributedLabelDelegate tap methods, which will not be called for this link.
 */
@property (nonatomic, copy) BITAttributedLabelLinkBlock linkTapBlock;

/**
 A block called when this link is long-pressed.
 If non-nil, long pressing on this link will call this block instead of the
 @c BITAttributedLabelDelegate long press methods, which will not be called for this link.
 */
@property (nonatomic, copy) BITAttributedLabelLinkBlock linkLongPressBlock;

/**
 Initializes a link using the attribute dictionaries specified.

 @param attributes         The @c attributes property for the link.
 @param activeAttributes   The @c activeAttributes property for the link.
 @param inactiveAttributes The @c inactiveAttributes property for the link.
 @param result             An @c NSTextCheckingResult representing the link's location and type.

 @return The initialized link object.
 */
- (instancetype)initWithAttributes:(NSDictionary *)attributes
                  activeAttributes:(NSDictionary *)activeAttributes
                inactiveAttributes:(NSDictionary *)inactiveAttributes
                textCheckingResult:(NSTextCheckingResult *)result;

/**
 Initializes a link using the attribute dictionaries set on a specified label.

 @param label  The attributed label from which to inherit attribute dictionaries.
 @param result An @c NSTextCheckingResult representing the link's location and type.

 @return The initialized link object.
 */
- (instancetype)initWithAttributesFromLabel:(BITAttributedLabel*)label
                         textCheckingResult:(NSTextCheckingResult *)result;

@end
