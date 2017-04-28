//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "MediaStreamItf.h"

using namespace tgvoip;

void MediaStreamItf::SetCallback(size_t (*f)(unsigned char *, size_t, void*), void* param){
	callback=f;
	callbackParam=param;
}

size_t MediaStreamItf::InvokeCallback(unsigned char *data, size_t length){
	return (*callback)(data, length, callbackParam);
}
