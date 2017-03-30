#import <Foundation/Foundation.h>

#import "ASCommon.h"

void __tgvoip_call_tglog(char* format, ...){
	va_list args;
	va_start(args, format);
	TGLogv([[NSString alloc]initWithCString:format], args);
	va_end(args);
}
