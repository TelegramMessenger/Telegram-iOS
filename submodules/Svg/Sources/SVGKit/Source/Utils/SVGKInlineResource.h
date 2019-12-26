//
//  SVGKInlineResource.h
//  SVGKit-iOS
//
//  Created by lizhuoli on 2018/11/2.
//  Copyright © 2018 na. All rights reserved.
//

#import "SVGKDefine.h"

/** Contains some inline resource define, such as default SVG, broekn image string, etc */

NS_ASSUME_NONNULL_BEGIN

/** Return the brkoken image base64 string */
FOUNDATION_EXPORT NSString * const SVGKGetBrokenImageString(void);
/** Return the shared broken image representation */
FOUNDATION_EXPORT UIImage * const SVGKGetBrokenImageRepresentation(void);
/** Return the default empty SVG content string */
FOUNDATION_EXPORT NSString * const SVGKGetDefaultContentString(void);

NS_ASSUME_NONNULL_END
