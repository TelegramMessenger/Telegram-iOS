//
//  SVGParserLinearGradient.m
//  SVGPad
//
//  Created by Kevin Stich on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SVGKParserGradient.h"

#import "SVGElement_ForParser.h"

#import "SVGGradientStop.h"

#import "SVGGradientElement.h"
#import "SVGLinearGradientElement.h"
#import "SVGRadialGradientElement.h"

@interface SVGKParserGradient ()
@property (nonatomic) NSArray *supportedNamespaces;
@property (nonatomic) NSArray *supportedTags;
@end

@implementation SVGKParserGradient

-(NSArray *)supportedNamespaces
{
    if( _supportedNamespaces == nil )
        _supportedNamespaces = @[@"http://www.w3.org/2000/svg"];
    return _supportedNamespaces;
}

-(NSArray *)supportedTags
{
    if( _supportedTags == nil )
        _supportedTags = @[@"linearGradient", @"radialGradient", @"stop"];
    return _supportedTags;
}

-(Node *)handleStartElement:(NSString *)name document:(SVGKSource *)document namePrefix:(NSString *)prefix namespaceURI:(NSString *)XMLNSURI attributes:(NSMutableDictionary *)attributes parseResult:(SVGKParseResult *)parseResult parentNode:(Node *)parentNode
{    
    Node *returnObject = nil;
    
    if( [name isEqualToString:@"linearGradient"] )
    {
        returnObject = currentElement = [[SVGLinearGradientElement alloc] initWithQualifiedName:name inNameSpaceURI:XMLNSURI attributes:attributes];
        [currentElement postProcessAttributesAddingErrorsTo:parseResult];
        
		/** No need to "store" anything; the node has been parsed, it'll be added to the DOM tree, and accessible later via DOM methods -- which is what the SVG spec expects us to do */
    }
    else if( [name isEqualToString:@"radialGradient"] ) {
        returnObject = currentElement = [[SVGRadialGradientElement alloc] initWithQualifiedName:name inNameSpaceURI:XMLNSURI attributes:attributes];
        [currentElement postProcessAttributesAddingErrorsTo:parseResult];
    }
    else if( [name isEqualToString:@"stop"] )
    {
        SVGGradientStop *gradientStop = [[SVGGradientStop alloc] initWithQualifiedName:name inNameSpaceURI:XMLNSURI attributes:attributes];
        
        [gradientStop postProcessAttributesAddingErrorsTo:parseResult];
        returnObject = gradientStop;       
        
        [currentElement addStop:gradientStop];
    }
    
//    var linearGrad:SVGLinearGradient = grad as SVGLinearGradient;
//                                            
//                                            if("@x1" in xml_grad)
//                                                        linearGrad.x1 = xml_grad.@x1;
//                                            else if(linearGrad.x1 == null)
//                                                        linearGrad.x1 = "0%";
//                                            
//                                            if("@y1" in xml_grad)
//                                                        linearGrad.y1 = xml_grad.@y1;
//                                            else if(linearGrad.y1 == null)
//                                                        linearGrad.y1 = "0%";
//                                            
//                                            if("@x2" in xml_grad)
//                                                        linearGrad.x2 = xml_grad.@x2;
//                                            else if(linearGrad.x2 == null)
//                                                        linearGrad.x2 = "100%";
//                                            
//                                            if("@y2" in xml_grad)
//                                                        linearGrad.y2 = xml_grad.@y2;
//                                            else if(linearGrad.y2 == null)
//                                                        linearGrad.y2 = "0%";
    return returnObject;
}

-(void)handleEndElement:(Node *)newNode document:(SVGKSource *)document parseResult:(SVGKParseResult *)parseResult
{
	
}

//-(void)dealloc
//{
//    currentElement = nil;
//    [super dealloc];
//}


@end


/*private static function parseGradient(id:String, svg:XML, storeObject:Object):SVGGradient {
                         id = StringUtil.ltrim(id, "#");
                         
                         if(storeObject[id]!=null)
                                 return storeObject[id];
                                                 
                         var xml_grad:XML = svg..*.(attribute("id")==id)[0];
                         
                         if(xml_grad == null)
                                 return null;
                         
                         var grad:SVGGradient;
                         
                         switch(xml_grad.localName().toLowerCase()){
                                 case "lineargradient": 
                                         grad = new SVGLinearGradient(); break;
                                 case "radialgradient" :
                                         grad = new SVGRadialGradient(); break;
                         }
                         
                         //inherits the href reference
                         var xlink:Namespace = new Namespace("http://www.w3.org/1999/xlink");
                         if(xml_grad.@xlink::href.length()>0){
                                 var baseGradient:SVGGradient = parseGradient(xml_grad.@xlink::href, svg, storeObject);
                                 if(baseGradient)
                                         baseGradient.copyTo(grad);
                         }
                         //
                         
                         if("@gradientUnits" in xml_grad)
                                 grad.gradientUnits = xml_grad.@gradientUnits;
                         else
                                 grad.gradientUnits = "objectBoundingBox";
                         
                         if("@gradientTransform" in xml_grad)
                                 grad.transform = parseTransformation(xml_grad.@gradientTransform);
                         
                         switch(grad.type){
                                 case GradientType.LINEAR : {
                                         var linearGrad:SVGLinearGradient = grad as SVGLinearGradient;
                                         
                                         if("@x1" in xml_grad)
                                                 linearGrad.x1 = xml_grad.@x1;
                                         else if(linearGrad.x1 == null)
                                                 linearGrad.x1 = "0%";
                                         
                                         if("@y1" in xml_grad)
                                                 linearGrad.y1 = xml_grad.@y1;
                                         else if(linearGrad.y1 == null)
                                                 linearGrad.y1 = "0%";
                                         
                                         if("@x2" in xml_grad)
                                                 linearGrad.x2 = xml_grad.@x2;
                                         else if(linearGrad.x2 == null)
                                                 linearGrad.x2 = "100%";
                                         
                                         if("@y2" in xml_grad)
                                                 linearGrad.y2 = xml_grad.@y2;
                                         else if(linearGrad.y2 == null)
                                                 linearGrad.y2 = "0%";
 
                                         break;
                                 }
                                 case GradientType.RADIAL : {
                                         var radialGrad:SVGRadialGradient = grad as SVGRadialGradient;
                                         
                                         if("@cx" in xml_grad)
                                                 radialGrad.cx = xml_grad.@cx;
                                         else if(radialGrad.cx==null)
                                                 radialGrad.cx = "50%";
                                         
                                         if("@cy" in xml_grad)
                                                 radialGrad.cy = xml_grad.@cy;
                                         else if(radialGrad.cy==null)
                                                 radialGrad.cy = "50%";
                                         
                                         if("@r" in xml_grad)
                                                 radialGrad.r = xml_grad.@r;
                                         else if(radialGrad.r == null)
                                                 radialGrad.r = "50%";
                                         
                                         if("@fx" in xml_grad)
                                                 radialGrad.fx = xml_grad.@fx;
                                         else if(radialGrad.fx==null)
                                                 radialGrad.fx = radialGrad.cx;
                                         
                                         if("@fy" in xml_grad)
                                                 radialGrad.fy = xml_grad.@fy;
                                         else if(radialGrad.fy==null)
                                                 radialGrad.fy = radialGrad.cy;
                                         
                                         break;
                                 }
                         }
                         
                         switch(xml_grad.@spreadMethod){
                                 case "pad" : grad.spreadMethod = SpreadMethod.PAD; break;
                                 case "reflect" : grad.spreadMethod = SpreadMethod.REFLECT; break;
                                 case "repeat" : grad.spreadMethod = SpreadMethod.REPEAT; break;
                                 default: grad.spreadMethod = SpreadMethod.PAD; break
                         }
                         
                         if(grad.colors == null)
                                 grad.colors = new Array();
                         
                         if(grad.alphas==null)
                                 grad.alphas = new Array();
                         
                         if(grad.ratios==null)
                                 grad.ratios = new Array();
                         
                         for each(var stop:XML in xml_grad.*::stop){
                                 var stopStyle:StyleDeclaration = new StyleDeclaration();
                                 
                                 if("@stop-opacity" in stop)
                                         stopStyle.setProperty("stop-opacity", stop.@["stop-opacity"]);
                                 
                                 if("@stop-color" in stop)
                                         stopStyle.setProperty("stop-color", stop.@["stop-color"]);
                                 
                                 if("@style" in stop){
                                         stopStyle.fromString(stop.@style);
                                 }
                                 
                                 grad.colors.push( SVGColorUtils.parseToUint(stopStyle.getPropertyValue("stop-color")) );
                                 grad.alphas.push( stopStyle.getPropertyValue("stop-opacity" ) != null ? Number(stopStyle.getPropertyValue("stop-opacity")) : 1 );
                                 
                                 var offset:Number = Number(StringUtil.rtrim(stop.@offset, "%"));
                                 if(String(stop.@offset).indexOf("%") > -1){
                                         offset/=100;
                                 }
                                 grad.ratios.push( offset*255 );
                         }
                         
                         //Save the gradient definition
                         storeObject[id] = grad;
                         //
                         
                         return grad;
*/
