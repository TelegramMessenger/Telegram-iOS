//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "DarwinSpecific.h"

#import <Foundation/Foundation.h>

using namespace tgvoip;

void DarwinSpecific::GetSystemName(char* buf, size_t len){
	NSString* v=[[NSProcessInfo processInfo] operatingSystemVersionString];
	strcpy(buf, [v UTF8String]);
	//[v getCString:buf maxLength:sizeof(buf) encoding:NSUTF8StringEncoding];
}
