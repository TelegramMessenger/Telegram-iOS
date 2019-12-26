/*!
 
 SVGKit - https://github.com/SVGKit/SVGKit
 
 THE MOST IMPORTANT ELEMENTS YOU'LL INTERACT WITH:
 
 1. SVGKImage = contains most of the convenience methods for loading / reading / displaying SVG files
 2. SVGKImageView = the easiest / fastest way to display an SVGKImage on screen
 3. SVGKLayer = the low-level way of getting an SVG as a bunch of layers
 
 SVGKImage makes heavy use of the following classes - you'll often use these classes (most of them given to you by an SVGKImage):
 
 4. SVGKSource = the "file" or "URL" for loading the SVG data
 5. SVGKParseResult = contains the parsed SVG file AND/OR the list of errors during parsing
 
 */

#import "SVGKDefine.h"


// MARK: - Framework Header File Content

@interface SVGKit : NSObject

+ (void) enableLogging;

@end

//! Project version number for SVGKitFramework-iOS.
FOUNDATION_EXPORT double SVGKitFramework_VersionNumber;

//! Project version string for SVGKitFramework-iOS.
FOUNDATION_EXPORT const unsigned char SVGKitFramework_VersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SVGKitFramework_iOS/PublicHeader.h>

// Core DOM
#import "AppleSucksDOMImplementation.h"
#import "Attr.h"
#import "CDATASection.h"
#import "CharacterData.h"
#import "Comment.h"
#import "CSSStyleDeclaration.h"
#import "CSSRule.h"
#import "CSSStyleSheet.h"
#import "CSSStyleRule.h"
#import "CSSRuleList.h"
#import "CSSRuleList+Mutable.h"
#import "CSSPrimitiveValue.h"
#import "CSSPrimitiveValue_ConfigurablePixelsPerInch.h"
#import "CSSValueList.h"
#import "CSSValue_ForSubclasses.h"
#import "CSSValue.h"
#import "Document+Mutable.h"
#import "Document.h"
#import "DocumentCSS.h"
#import "DocumentStyle.h"
#import "StyleSheetList+Mutable.h"
#import "StyleSheetList.h"
#import "StyleSheet.h"
#import "MediaList.h"
#import "DocumentFragment.h"
#import "DocumentType.h"
#import "DOMHelperUtilities.h"
#import "Element.h"
#import "EntityReference.h"
#import "NamedNodeMap.h"
#import "NamedNodeMap_Iterable.h"
#import "Node+Mutable.h"
#import "Node.h"
#import "NodeList+Mutable.h"
#import "NodeList.h"
#import "ProcessingInstruction.h"
#import "Text.h"
#import "DOMGlobalSettings.h"

// SVG DOM
#import "SVGAngle.h"
#import "SVGAnimatedPreserveAspectRatio.h"
#import "SVGDefsElement.h"
#import "SVGDocument.h"
#import "SVGDocument_Mutable.h"
#import "SVGElementInstance.h"
#import "SVGElementInstance_Mutable.h"
#import "SVGElementInstanceList.h"
#import "SVGElementInstanceList_Internal.h"
#import "SVGGElement.h"
#import "SVGStylable.h"
#import "SVGLength.h"
#import "SVGMatrix.h"
#import "SVGNumber.h"
#import "SVGPoint.h"
#import "SVGPreserveAspectRatio.h"
#import "SVGRect.h"
#import "SVGSVGElement_Mutable.h"
#import "SVGTransform.h"
#import "SVGUseElement.h"
#import "SVGUseElement_Mutable.h"
#import "SVGViewSpec.h"
#import "SVGHelperUtilities.h"
#import "SVGTransformable.h"
#import "SVGFitToViewBox.h"
#import "SVGTextPositioningElement.h"
#import "SVGTextContentElement.h"
#import "SVGTextPositioningElement_Mutable.h"
#import "ConverterSVGToCALayer.h"
#import "SVGGradientElement.h"
#import "SVGGradientStop.h"
#import "SVGLinearGradientElement.h"
#import "SVGRadialGradientElement.h"
#import "SVGStyleCatcher.h"
#import "SVGStyleElement.h"
#import "SVGCircleElement.h"
#import "SVGDescriptionElement.h"
#import "SVGElement.h"
#import "SVGElement_ForParser.h"
#import "SVGEllipseElement.h"
#import "SVGGroupElement.h"
#import "SVGImageElement.h"
#import "SVGLineElement.h"
#import "SVGPathElement.h"
#import "SVGPolygonElement.h"
#import "SVGPolylineElement.h"
#import "SVGRectElement.h"
#import "BaseClassForAllSVGBasicShapes.h"
#import "BaseClassForAllSVGBasicShapes_ForSubclasses.h"
#import "SVGSVGElement.h"
#import "SVGTextElement.h"
#import "SVGTitleElement.h"
#import "SVGSwitchElement.h"
#import "SVGClipPathElement.h"
#import "TinySVGTextAreaElement.h"

// Parser

#import "SVGKImage+CGContext.h"
#import "SVGKExporterNSData.h"
#if SVGKIT_MAC
#import "SVGKExporterNSImage.h"
#else
#import "SVGKExporterUIImage.h"
#endif
#import "SVGKSourceLocalFile.h"
#import "SVGKSourceString.h"
#import "SVGKSourceURL.h"
#import "SVGKParserDefsAndUse.h"
#import "SVGKParserDOM.h"
#import "SVGKParserGradient.h"
#import "SVGKParserPatternsAndGradients.h"
#import "SVGKParserStyles.h"
#import "SVGKParserSVG.h"
#import "SVGKParser.h"
#import "SVGKParseResult.h"
#import "SVGKParserExtension.h"
#import "SVGKPointsAndPathsParser.h"
#import "CALayer+RecursiveClone.h"
#import "SVGGradientLayer.h"
#import "SVGTextLayer.h"
#import "CALayerWithChildHitTest.h"
#import "CAShapeLayerWithHitTest.h"
#import "CGPathAdditions.h"
#import "SVGKLayer.h"
#import "SVGKImage.h"
#import "SVGKSource.h"
#import "NSCharacterSet+SVGKExtensions.h"
#import "SVGKFastImageView.h"
#import "SVGKImageView.h"
#import "SVGKLayeredImageView.h"
#import "SVGKPattern.h"
#import "SVGUtils.h"
#if SVGKIT_MAC
#import "SVGKImageRep.h"
#endif
#import "NSData+NSInputStream.h"
#import "SVGKSourceNSData.h"
#import "SVGKInlineResource.h"
