//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef TGVOIP_DARWINSPECIFIC_H
#define TGVOIP_DARWINSPECIFIC_H

#include <string>

namespace tgvoip {
class DarwinSpecific{
public:
	static void GetSystemName(char* buf, size_t len);
};
}

#endif //TGVOIP_DARWINSPECIFIC_H
