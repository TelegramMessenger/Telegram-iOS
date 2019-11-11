//
//  ASLayoutElement.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLayoutElementPrivate.h>
#import <AsyncDisplayKit/ASLayoutElementExtensibility.h>
#import <AsyncDisplayKit/ASDimensionInternal.h>
#import <AsyncDisplayKit/ASStackLayoutElement.h>
#import <AsyncDisplayKit/ASAbsoluteLayoutElement.h>
#import <AsyncDisplayKit/ASTraitCollection.h>
#import <AsyncDisplayKit/ASAsciiArtBoxCreator.h>
#import <AsyncDisplayKit/ASLocking.h>

@class ASLayout;
@class ASLayoutSpec;
@protocol ASLayoutElementStylability;

@protocol ASTraitEnvironment;

NS_ASSUME_NONNULL_BEGIN

/** A constant that indicates that the parent's size is not yet determined in a given dimension. */
AS_EXTERN CGFloat const ASLayoutElementParentDimensionUndefined;

/** A constant that indicates that the parent's size is not yet determined in either dimension. */
AS_EXTERN CGSize const ASLayoutElementParentSizeUndefined;

/** Type of ASLayoutElement  */
typedef NS_ENUM(NSUInteger, ASLayoutElementType) {
  ASLayoutElementTypeLayoutSpec,
  ASLayoutElementTypeDisplayNode
};

#pragma mark - ASLayoutElement

/**
 * The ASLayoutElement protocol declares a method for measuring the layout of an object. A layout
 * is defined by an ASLayout return value, and must specify 1) the size (but not position) of the
 * layoutElement object, and 2) the size and position of all of its immediate child objects. The tree 
 * recursion is driven by parents requesting layouts from their children in order to determine their 
 * size, followed by the parents setting the position of the children once the size is known
 *
 * The protocol also implements a "family" of LayoutElement protocols. These protocols contain layout 
 * options that can be used for specific layout specs. For example, ASStackLayoutSpec has options
 * defining how a layoutElement should shrink or grow based upon available space.
 *
 * These layout options are all stored in an ASLayoutOptions class (that is defined in ASLayoutElementPrivate).
 * Generally you needn't worry about the layout options class, as the layoutElement protocols allow all direct
 * access to the options via convenience properties. If you are creating custom layout spec, then you can
 * extend the backing layout options class to accommodate any new layout options.
 */
@protocol ASLayoutElement <ASLayoutElementExtensibility, ASTraitEnvironment, ASLayoutElementAsciiArtProtocol>

#pragma mark - Getter

/**
 * @abstract Returns type of layoutElement
 */
@property (nonatomic, readonly) ASLayoutElementType layoutElementType;

/**
 * @abstract A size constraint that should apply to this ASLayoutElement.
 */
@property (nonatomic, readonly) ASLayoutElementStyle *style;

/**
 * @abstract Returns all children of an object which class conforms to the ASLayoutElement protocol
 */
- (nullable NSArray<id<ASLayoutElement>> *)sublayoutElements;

#pragma mark - Calculate layout

/**
 * @abstract Asks the node to return a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver (and its children, if the box layout model is used).
 *
 * @discussion Though this method does not set the bounds of the view, it does have side effects--caching both the
 * constraint and the result.
 *
 * @warning Subclasses must not override this; it caches results from -calculateLayoutThatFits:.  Calling this method may
 * be expensive if result is not cached.
 *
 * @see [ASDisplayNode(Subclassing) calculateLayoutThatFits:]
 */
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize;

/**
 * Call this on children layoutElements to compute their layouts within your implementation of -calculateLayoutThatFits:.
 *
 * @warning You may not override this method. Override -calculateLayoutThatFits: instead.
 * @warning In almost all cases, prefer the use of ASCalculateLayout in ASLayout
 *
 * @param constrainedSize Specifies a minimum and maximum size. The receiver must choose a size that is in this range.
 * @param parentSize The parent node's size. If the parent component does not have a final size in a given dimension,
 *                  then it should be passed as ASLayoutElementParentDimensionUndefined (for example, if the parent's width
 *                  depends on the child's size).
 *
 * @discussion Though this method does not set the bounds of the view, it does have side effects--caching both the
 * constraint and the result.
 *
 * @return An ASLayout instance defining the layout of the receiver (and its children, if the box layout model is used).
 */
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize;

/**
 * Override this method to compute your layoutElement's layout.
 *
 * @discussion Why do you need to override -calculateLayoutThatFits: instead of -layoutThatFits:parentSize:?
 * The base implementation of -layoutThatFits:parentSize: does the following for you:
 * 1. First, it uses the parentSize parameter to resolve the nodes's size (the one assigned to the size property).
 * 2. Then, it intersects the resolved size with the constrainedSize parameter. If the two don't intersect,
 *    constrainedSize wins. This allows a component to always override its childrens' sizes when computing its layout.
 *    (The analogy for UIView: you might return a certain size from -sizeThatFits:, but a parent view can always override
 *    that size and set your frame to any size.)
 * 3. It caches it result for reuse
 *
 * @param constrainedSize A min and max size. This is computed as described in the description. The ASLayout you
 *                        return MUST have a size between these two sizes.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize;

/**
 * In certain advanced cases, you may want to override this method. Overriding this method allows you to receive the
 * layoutElement's size, parentSize, and constrained size. With these values you could calculate the final constrained size
 * and call -calculateLayoutThatFits: with the result.
 *
 * @warning Overriding this method should be done VERY rarely.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize;

- (BOOL)implementsLayoutMethod;

@end

#pragma mark - ASLayoutElementStyle

AS_EXTERN NSString * const ASLayoutElementStyleWidthProperty;
AS_EXTERN NSString * const ASLayoutElementStyleMinWidthProperty;
AS_EXTERN NSString * const ASLayoutElementStyleMaxWidthProperty;

AS_EXTERN NSString * const ASLayoutElementStyleHeightProperty;
AS_EXTERN NSString * const ASLayoutElementStyleMinHeightProperty;
AS_EXTERN NSString * const ASLayoutElementStyleMaxHeightProperty;

AS_EXTERN NSString * const ASLayoutElementStyleSpacingBeforeProperty;
AS_EXTERN NSString * const ASLayoutElementStyleSpacingAfterProperty;
AS_EXTERN NSString * const ASLayoutElementStyleFlexGrowProperty;
AS_EXTERN NSString * const ASLayoutElementStyleFlexShrinkProperty;
AS_EXTERN NSString * const ASLayoutElementStyleFlexBasisProperty;
AS_EXTERN NSString * const ASLayoutElementStyleAlignSelfProperty;
AS_EXTERN NSString * const ASLayoutElementStyleAscenderProperty;
AS_EXTERN NSString * const ASLayoutElementStyleDescenderProperty;

AS_EXTERN NSString * const ASLayoutElementStyleLayoutPositionProperty;

@protocol ASLayoutElementStyleDelegate <NSObject>
- (void)style:(__kindof ASLayoutElementStyle *)style propertyDidChange:(NSString *)propertyName;
@end

@interface ASLayoutElementStyle : NSObject <ASStackLayoutElement, ASAbsoluteLayoutElement, ASLayoutElementExtensibility, ASLocking>

/**
 * @abstract Initializes the layoutElement style with a specified delegate
 */
- (instancetype)initWithDelegate:(id<ASLayoutElementStyleDelegate>)delegate;

/**
 * @abstract The object that acts as the delegate of the style.
 *
 * @discussion The delegate must adopt the ASLayoutElementStyleDelegate protocol. The delegate is not retained.
 */
@property (nullable, nonatomic, weak, readonly) id<ASLayoutElementStyleDelegate> delegate;


#pragma mark - Sizing

/**
 * @abstract The width property specifies the width of the content area of an ASLayoutElement.
 * The minWidth and maxWidth properties override width.
 * Defaults to ASDimensionAuto
 */
@property (nonatomic) ASDimension width;

/**
 * @abstract The height property specifies the height of the content area of an ASLayoutElement
 * The minHeight and maxHeight properties override height.
 * Defaults to ASDimensionAuto
 */
@property (nonatomic) ASDimension height;

/**
 * @abstract The minHeight property is used to set the minimum height of a given element. It prevents the used value
 * of the height property from becoming smaller than the value specified for minHeight.
 * The value of minHeight overrides both maxHeight and height.
 * Defaults to ASDimensionAuto
 */
@property (nonatomic) ASDimension minHeight;

/**
 * @abstract The maxHeight property is used to set the maximum height of an element. It prevents the used value of the
 * height property from becoming larger than the value specified for maxHeight.
 * The value of maxHeight overrides height, but minHeight overrides maxHeight.
 * Defaults to ASDimensionAuto
 */
@property (nonatomic) ASDimension maxHeight;

/**
 * @abstract The minWidth property is used to set the minimum width of a given element. It prevents the used value of
 * the width property from becoming smaller than the value specified for minWidth.
 * The value of minWidth overrides both maxWidth and width.
 * Defaults to ASDimensionAuto
 */
@property (nonatomic) ASDimension minWidth;

/**
 * @abstract The maxWidth property is used to set the maximum width of a given element. It prevents the used value of
 * the width property from becoming larger than the value specified for maxWidth.
 * The value of maxWidth overrides width, but minWidth overrides maxWidth.
 * Defaults to ASDimensionAuto
 */
@property (nonatomic) ASDimension maxWidth;

#pragma mark - ASLayoutElementStyleSizeHelpers

/**
 * @abstract Provides a suggested size for a layout element. If the optional minSize or maxSize are provided, 
 * and the preferredSize exceeds these, the minSize or maxSize will be enforced. If this optional value is not 
 * provided, the layout element’s size will default to it’s intrinsic content size provided calculateSizeThatFits:
 * 
 * @discussion This method is optional, but one of either preferredSize or preferredLayoutSize is required
 * for nodes that either have no intrinsic content size or 
 * should be laid out at a different size than its intrinsic content size. For example, this property could be 
 * set on an ASImageNode to display at a size different from the underlying image size.
 *
 * @warning Calling the getter when the size's width or height are relative will cause an assert.
 */
@property (nonatomic) CGSize preferredSize;

 /**
 * @abstract An optional property that provides a minimum size bound for a layout element. If provided, this restriction will 
 * always be enforced. If a parent layout element’s minimum size is smaller than its child’s minimum size, the child’s  
 * minimum size will be enforced and its size will extend out of the layout spec’s.  
 * 
 * @discussion For example, if you set a preferred relative width of 50% and a minimum width of 200 points on an
 * element in a full screen container, this would result in a width of 160 points on an iPhone screen. However, 
 * since 160 pts is lower than the minimum width of 200 pts, the minimum width would be used.
 */
@property (nonatomic) CGSize minSize;
- (CGSize)minSize UNAVAILABLE_ATTRIBUTE;

/**
 * @abstract An optional property that provides a maximum size bound for a layout element. If provided, this restriction will 
 * always be enforced.  If a child layout element’s maximum size is smaller than its parent, the child’s maximum size will 
 * be enforced and its size will extend out of the layout spec’s.  
 * 
 * @discussion For example, if you set a preferred relative width of 50% and a maximum width of 120 points on an
 * element in a full screen container, this would result in a width of 160 points on an iPhone screen. However, 
 * since 160 pts is higher than the maximum width of 120 pts, the maximum width would be used.
 */
@property (nonatomic) CGSize maxSize;
- (CGSize)maxSize UNAVAILABLE_ATTRIBUTE;

/**
 * @abstract Provides a suggested RELATIVE size for a layout element. An ASLayoutSize uses percentages rather
 * than points to specify layout. E.g. width should be 50% of the parent’s width. If the optional minLayoutSize or
 * maxLayoutSize are provided, and the preferredLayoutSize exceeds these, the minLayoutSize or maxLayoutSize 
 * will be enforced. If this optional value is not provided, the layout element’s size will default to its intrinsic content size 
 * provided calculateSizeThatFits:
 */
@property (nonatomic) ASLayoutSize preferredLayoutSize;

/**
 * @abstract An optional property that provides a minimum RELATIVE size bound for a layout element. If provided, this
 * restriction will always be enforced. If a parent layout element’s minimum relative size is smaller than its child’s minimum
 * relative size, the child’s minimum relative size will be enforced and its size will extend out of the layout spec’s.
 */
@property (nonatomic) ASLayoutSize minLayoutSize;

/**
 * @abstract An optional property that provides a maximum RELATIVE size bound for a layout element. If provided, this
 * restriction will always be enforced. If a parent layout element’s maximum relative size is smaller than its child’s maximum
 * relative size, the child’s maximum relative size will be enforced and its size will extend out of the layout spec’s.
 */
@property (nonatomic) ASLayoutSize maxLayoutSize;

@end

#pragma mark - ASLayoutElementStylability

@protocol ASLayoutElementStylability

- (instancetype)styledWithBlock:(AS_NOESCAPE void (^)(__kindof ASLayoutElementStyle *style))styleBlock;

@end

NS_ASSUME_NONNULL_END
