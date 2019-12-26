//
//  SVGUtils.m
//  SVGKit
//
//  Copyright Matt Rajca 2010-2011. All rights reserved.
//

#import "SVGUtils.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define MAX_ACCUM 64
#define NUM_COLORS 148


SVGColor ColorValueWithName (const char *name);

static const char *gColorNames[NUM_COLORS] = {
	"aliceblue",
	"antiquewhite",
	"aqua",
	"aquamarine",
	"azure",
	"beige",
	"bisque",
	"black",
	"blanchedalmond",
	"blue",
	"blueviolet",
	"brown",
	"burlywood",
	"cadetblue",
	"chartreuse",
	"chocolate",
	"coral",
	"cornflowerblue",
	"cornsilk",
	"crimson",
	"cyan",
	"darkblue",
	"darkcyan",
	"darkgoldenrod",
	"darkgray",
	"darkgreen",
	"darkgrey",
	"darkkhaki",
	"darkmagenta",
	"darkolivegreen",
	"darkorange",
	"darkorchid",
	"darkred",
	"darksalmon",
	"darkseagreen",
	"darkslateblue",
	"darkslategray",
	"darkslategrey",
	"darkturquoise",
	"darkviolet",
	"deeppink",
	"deepskyblue",
	"dimgray",
	"dimgrey",
	"dodgerblue",
	"firebrick",
	"floralwhite",
	"forestgreen",
	"fuchsia",
	"gainsboro",
	"ghostwhite",
	"gold",
	"goldenrod",
	"gray",
	"green",
	"greenyellow",
	"grey",
	"honeydew",
	"hotpink",
	"indianred",
	"indigo",
	"ivory",
	"khaki",
	"lavender",
	"lavenderblush",
	"lawngreen",
	"lemonchiffon",
	"lightblue",
	"lightcoral",
	"lightcyan",
	"lightgoldenrodyellow",
	"lightgray",
	"lightgreen",
	"lightgrey",
	"lightpink",
	"lightsalmon",
	"lightseagreen",
	"lightskyblue",
	"lightslategray",
	"lightslategrey",
	"lightsteelblue",
	"lightyellow",
	"lime",
	"limegreen",
	"linen",
	"magenta",
	"maroon",
	"mediumaquamarine",
	"mediumblue",
	"mediumorchid",
	"mediumpurple",
	"mediumseagreen",
	"mediumslateblue",
	"mediumspringgreen",
	"mediumturquoise",
	"mediumvioletred",
	"midnightblue",
	"mintcream",
	"mistyrose",
	"moccasin",
	"navajowhite",
	"navy",
	"oldlace",
	"olive",
	"olivedrab",
	"orange",
	"orangered",
	"orchid",
	"palegoldenrod",
	"palegreen",
	"paleturquoise",
	"palevioletred",
	"papayawhip",
	"peachpuff",
	"peru",
	"pink",
	"plum",
	"powderblue",
	"purple",
	"red",
	"rosybrown",
	"royalblue",
	"saddlebrown",
	"salmon",
	"sandybrown",
	"seagreen",
	"seashell",
	"sienna",
	"silver",
	"skyblue",
	"slateblue",
	"slategray",
	"slategrey",
	"snow",
	"springgreen",
	"steelblue",
	"tan",
	"teal",
	"thistle",
	"tomato",
	"turquoise",
	"violet",
	"wheat",
	"white",
	"whitesmoke",
	"yellow",
	"yellowgreen",
    // CSS Color
    "transparent"
};

static const SVGColor gColorValues[NUM_COLORS] = {
	(SVGColor) { 240,248,255,255 }, (SVGColor) { 250,235,215,255 },
	(SVGColor) { 0,255,255,255 }, (SVGColor) { 127,255,212,255 },
	(SVGColor) { 240,255,255,255 }, (SVGColor) { 245,245,220,255 },
	(SVGColor) { 255,228,196,255 }, (SVGColor) { 0,0,0,255 },
	(SVGColor) { 255,235,205,255 }, (SVGColor) { 0,0,255,255 },
	(SVGColor) { 138,43,226,255 }, (SVGColor) { 165,42,42,255 },
	(SVGColor) { 222,184,135,255 }, (SVGColor) { 95,158,160,255 },
	(SVGColor) { 127,255,0,255 }, (SVGColor) { 210,105,30,255 },
	(SVGColor) { 255,127,80,255 }, (SVGColor) { 100,149,237,255 },
	(SVGColor) { 255,248,220,255 }, (SVGColor) { 220,20,60,255 },
	(SVGColor) { 0,255,255,255 }, (SVGColor) { 0,0,139,255 },
	(SVGColor) { 0,139,139,255 }, (SVGColor) { 184,134,11,255 },
	(SVGColor) { 169,169,169,255 }, (SVGColor) { 0,100,0,255 },
	(SVGColor) { 169,169,169,255 }, (SVGColor) { 189,183,107,255 },
	(SVGColor) { 139,0,139,255 }, (SVGColor) { 85,107,47,255 },
	(SVGColor) { 255,140,0,255 }, (SVGColor) { 153,50,204,255 },
	(SVGColor) { 139,0,0,255 }, (SVGColor) { 233,150,122,255 },
	(SVGColor) { 143,188,143,255 }, (SVGColor) { 72,61,139,255 },
	(SVGColor) { 47,79,79,255 }, (SVGColor) { 47,79,79,255 },
	(SVGColor) { 0,206,209,255 }, (SVGColor) { 148,0,211,255 },
	(SVGColor) { 255,20,147,255 }, (SVGColor) { 0,191,255,255 },
	(SVGColor) { 105,105,105,255 }, (SVGColor) { 105,105,105,255 },
	(SVGColor) { 30,144,255,255 }, (SVGColor) { 178,34,34,255 },
	(SVGColor) { 255,250,240,255 }, (SVGColor) { 34,139,34,255 },
	(SVGColor) { 255,0,255,255 }, (SVGColor) { 220,220,220,255 },
	(SVGColor) { 248,248,255,255 }, (SVGColor) { 255,215,0,255 },
	(SVGColor) { 218,165,32,255 }, (SVGColor) { 128,128,128,255 },
	(SVGColor) { 0,128,0,255 }, (SVGColor) { 173,255,47,255 },
	(SVGColor) { 128,128,128,255 }, (SVGColor) { 240,255,240,255 },
	(SVGColor) { 255,105,180,255 }, (SVGColor) { 205,92,92,255 },
	(SVGColor) { 75,0,130,255 }, (SVGColor) { 255,255,240,255 },
	(SVGColor) { 240,230,140,255 }, (SVGColor) { 230,230,250,255 },
	(SVGColor) { 255,240,245,255 }, (SVGColor) { 124,252,0,255 },
	(SVGColor) { 255,250,205,255 }, (SVGColor) { 173,216,230,255 },
	(SVGColor) { 240,128,128,255 }, (SVGColor) { 224,255,255,255 },
	(SVGColor) { 250,250,210,255 }, (SVGColor) { 211,211,211,255 },
	(SVGColor) { 144,238,144,255 }, (SVGColor) { 211,211,211,255 },
	(SVGColor) { 255,182,193,255 }, (SVGColor) { 255,160,122,255 },
	(SVGColor) { 32,178,170,255 }, (SVGColor) { 135,206,250,255 },
	(SVGColor) { 119,136,153,255 }, (SVGColor) { 119,136,153,255 },
	(SVGColor) { 176,196,222,255 }, (SVGColor) { 255,255,224,255 },
	(SVGColor) { 0,255,0,255 }, (SVGColor) { 50,205,50,255 },
	(SVGColor) { 250,240,230,255 }, (SVGColor) { 255,0,255,255 },
	(SVGColor) { 128,0,0,255 }, (SVGColor) { 102,205,170,255 },
	(SVGColor) { 0,0,205,255 }, (SVGColor) { 186,85,211,255 },
	(SVGColor) { 147,112,219,255 }, (SVGColor) { 60,179,113,255 },
	(SVGColor) { 123,104,238,255 }, (SVGColor) { 0,250,154,255 },
	(SVGColor) { 72,209,204,255 }, (SVGColor) { 199,21,133,255 },
	(SVGColor) { 25,25,112,255 }, (SVGColor) { 245,255,250,255 },
	(SVGColor) { 255,228,225,255 }, (SVGColor) { 255,228,181,255 },
	(SVGColor) { 255,222,173,255 }, (SVGColor) { 0,0,128,255 },
	(SVGColor) { 253,245,230,255 }, (SVGColor) { 128,128,0,255 },
	(SVGColor) { 107,142,35,255 }, (SVGColor) { 255,165,0,255 },
	(SVGColor) { 255,69,0,255 }, (SVGColor) { 218,112,214,255 },
	(SVGColor) { 238,232,170,255 }, (SVGColor) { 152,251,152,255 },
	(SVGColor) { 175,238,238,255 }, (SVGColor) { 219,112,147,255 },
	(SVGColor) { 255,239,213,255 }, (SVGColor) { 255,218,185,255 },
	(SVGColor) { 205,133,63,255 }, (SVGColor) { 255,192,203,255 },
	(SVGColor) { 221,160,221,255 }, (SVGColor) { 176,224,230,255 },
	(SVGColor) { 128,0,128,255 }, (SVGColor) { 255,0,0,255 },
	(SVGColor) { 188,143,143,255 }, (SVGColor) { 65,105,225,255 },
	(SVGColor) { 139,69,19,255 }, (SVGColor) { 250,128,114,255 },
	(SVGColor) { 244,164,96,255 }, (SVGColor) { 46,139,87,255 },
	(SVGColor) { 255,245,238,255 }, (SVGColor) { 160,82,45,255 },
	(SVGColor) { 192,192,192,255 }, (SVGColor) { 135,206,235,255 },
	(SVGColor) { 106,90,205,255 }, (SVGColor) { 112,128,144,255 },
	(SVGColor) { 112,128,144,255 }, (SVGColor) { 255,250,250,255 },
	(SVGColor) { 0,255,127,255 }, (SVGColor) { 70,130,180,255 },
	(SVGColor) { 210,180,140,255 }, (SVGColor) { 0,128,128,255 },
	(SVGColor) { 216,191,216,255 }, (SVGColor) { 255,99,71,255 },
	(SVGColor) { 64,224,208,255 }, (SVGColor) { 238,130,238,255 },
	(SVGColor) { 245,222,179,255 }, (SVGColor) { 255,255,255,255 },
	(SVGColor) { 245,245,245,255 }, (SVGColor) { 255,255,0,255 },
	(SVGColor) { 154,205,50,255 },
    // CSS Color
    (SVGColor) { 0, 0, 0, 0}
};

SVGColor ColorValueWithName (const char *name) {
	int idx = -1;
	
	for (int n = 0; n < NUM_COLORS; n++) {
		if (!strcmp(gColorNames[n], name)) {
			idx = n;
			break;
		}
	}
	
	if (idx == -1) {
		return SVGColorMake(0, 0, 0, 255); // black
	}
	
	return gColorValues[idx];
}

SVGColor SVGColorMake (uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	SVGColor color = { .r = r, .g = g, .b = b, .a = a };
	return color;
}

typedef enum {
	PhaseNone = 0,
	PhaseRGB,
    PhaseRGBA
} Phase;

SVGColor SVGColorFromString (const char *string) {
	NSCAssert(string != NULL, @"NullPointerException: you gave us a null pointer, very bad thing to do...");
	SVGColor color;
	bzero(&color, sizeof(color));
	
	color.a = 0xFF;
	
	if (!strncmp(string, "rgb(", 4) || !strncmp(string, "rgba(", 5)) {
		size_t len = strlen(string);
		
		char accum[MAX_ACCUM];
		bzero(accum, MAX_ACCUM);
		
		int accumIdx = 0, currComponent = 0;
		Phase phase = PhaseNone;
		
		for (size_t n = 0; n < len; n++) {
			char c = string[n];
			
			if (c == '\n' || c == '\t' || c == ' ') {
				continue;
			}
			
            if (!strcmp(accum, "rgba(")) {
                phase = PhaseRGBA;
                bzero(accum, MAX_ACCUM);
                accumIdx = 0;
            } else if (!strcmp(accum, "rgb(")) {
				phase = PhaseRGB;
                bzero(accum, MAX_ACCUM);
                accumIdx = 0;
			}
			
			if (phase == PhaseRGB || phase == PhaseRGBA) {
				if (c == ',') {
					if (currComponent == 0) {
						color.r = atoi(accum);
						currComponent++;
					}
					else if (currComponent == 1) {
						color.g = atoi(accum);
						currComponent++;
					}
                    else if (phase == PhaseRGBA && currComponent == 2) {
                        color.b = atoi(accum);
                        currComponent++;
                    }
					bzero(accum, MAX_ACCUM);
					accumIdx = 0;
					
					continue;
				}
                else if (c == ')' && currComponent == 2) {
                    color.b = atoi(accum);
                    break;
                }
                else if (c == ')' && currComponent == 3) {
                    color.a = (uint8_t)lround(atof(accum) * 255.0f);
                    break;
                }
			}
			
			accum[accumIdx++] = c;
		}
	}
	else if (!strncmp(string, "#", 1)) {
		const char *hexString = string + 1;
		
		if (strlen(hexString) == 6)
		{
			char r[3], g[3], b[3];
			r[2] = g[2] = b[2] = '\0';
			
			strncpy(r, hexString, 2);
			strncpy(g, hexString + 2, 2);
			strncpy(b, hexString + 4, 2);
			
			color.r = strtol(r, NULL, 16);
			color.g = strtol(g, NULL, 16);
			color.b = strtol(b, NULL, 16);
		}
		else if( strlen(hexString) == 3 )
		{
			char r[2], g[2], b[2];
			r[1] = g[1] = b[1] = '\0';
			
			strncpy(r, hexString, 1);
			strncpy(g, hexString + 1, 1);
			strncpy(b, hexString + 2, 1);
			
			color.r = strtol(r, NULL, 16);
			color.g = strtol(g, NULL, 16);
			color.b = strtol(b, NULL, 16);
			
			/** because 3-digit hex notation "F" means "FF" ... "1" means "11" ... etc */
			color.r += color.r * 16;
			color.g += color.g * 16;
			color.b += color.b * 16;
		}
		else
		{
			color = SVGColorMake(0, 0, 0, 255);
		}
		
	}
	else {
		color = ColorValueWithName(string);
	}
	
	return color;
}

CGFloat SVGPercentageFromString (const char *string) {
	size_t len = strlen(string);
	
	if (string[len-1] != '%') {
		SVGKitLogWarn(@"Invalid percentage: %s", string);
		return -1;
	}
	
	return atoi(string) / 100.0f;
}

CGMutablePathRef createPathFromPointsInString (const char *string, boolean_t close) {
	CGMutablePathRef path = CGPathCreateMutable();
	
	size_t len = strlen(string);
	
	char accum[MAX_ACCUM];
	bzero(accum, MAX_ACCUM);
	
	int accumIdx = 0, currComponent = 0;
	
	for (size_t n = 0; n <= len; n++) {
		char c = string[n];
		
		if (c == '\n' || c == '\t' || c == ' ' || c == ',' || c == '\0') {
			accum[accumIdx] = '\0';
			
			static float x, y;
			
			if (currComponent == 0 && accumIdx != 0) {
				sscanf( accum, "%g", &x );
				currComponent++;
			}
			else if (currComponent == 1) {
				
				sscanf( accum, "%g", &y );
				
				if (CGPathIsEmpty(path)) {
					CGPathMoveToPoint(path, NULL, x, y);
				}
				else {
					CGPathAddLineToPoint(path, NULL, x, y);
				}
				
				currComponent = 0;
			}
			
			bzero(accum, MAX_ACCUM);
			accumIdx = 0;
		}
		else if (isdigit(c) || c == '-' || c == '.') { // is digit or decimal separator OR A MINUS SIGN!!! ?
			accum[accumIdx++] = c;
		}
	}
	
	if (close) {
		CGPathCloseSubpath(path);
	}
	
	return path;
}

CGColorRef CGColorWithSVGColor (SVGColor color) {
	CGColorRef outColor = NULL;
	
	outColor = [UIColor colorWithRed:RGB_N(color.r)
							   green:RGB_N(color.g)
								blue:RGB_N(color.b)
							   alpha:RGB_N(color.a)].CGColor;
	
	return outColor;
}
