//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_MEDIASTREAMINPUT_H
#define LIBTGVOIP_MEDIASTREAMINPUT_H

#include <string.h>

namespace tgvoip{
class MediaStreamItf{
public:
	virtual void Start()=0;
	virtual void Stop()=0;
	void SetCallback(size_t (*f)(unsigned char*, size_t, void*), void* param);

//protected:
	size_t InvokeCallback(unsigned char* data, size_t length);

private:
	size_t (*callback)(unsigned char*, size_t, void*);
	void* callbackParam;
};
}


#endif //LIBTGVOIP_MEDIASTREAMINPUT_H
