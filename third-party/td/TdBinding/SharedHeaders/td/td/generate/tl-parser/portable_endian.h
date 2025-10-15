// "License": Public Domain
// I, Mathias Panzenböck, place this file hereby into the public domain. Use it at your own risk for whatever you like.
// In case there are jurisdictions that don't support putting things in the public domain you can also consider it to
// be "dual licensed" under the BSD, MIT and Apache licenses, if you want to. This code is trivial anyway. Consider it
// an example on how to get the endian conversion functions on different platforms.

/* Originally cloned from https://gist.github.com/PkmX/63dd23f28ba885be53a5
 * Commit was: 1eca2ab34f2301b9641aa73d1016b951fff3fc39
 * Re-published at https://github.com/BenWiederhake/portable-endian.h to provide a means to submit patches and report issues. */

#ifndef PORTABLE_ENDIAN_H__
#define PORTABLE_ENDIAN_H__

#if (defined(_WIN16) || defined(_WIN32) || defined(_WIN64)) && !defined(__WINDOWS__)

#	define __WINDOWS__

#endif

#if defined(__linux__) || defined(__CYGWIN__) || defined(__sun)

#	include <endian.h>

#elif defined(__APPLE__)

#	include <libkern/OSByteOrder.h>

#	define htobe32(x) OSSwapHostToBigInt32(x)
#	define htole32(x) OSSwapHostToLittleInt32(x)
 
#	define htobe64(x) OSSwapHostToBigInt64(x)
#	define htole64(x) OSSwapHostToLittleInt64(x)

#	define __BYTE_ORDER    BYTE_ORDER
#	define __BIG_ENDIAN    BIG_ENDIAN
#	define __LITTLE_ENDIAN LITTLE_ENDIAN
#	define __PDP_ENDIAN    PDP_ENDIAN

#elif defined(__OpenBSD__)

#	include <sys/endian.h>

#elif defined(__NetBSD__) || defined(__FreeBSD__) || defined(__DragonFly__)

#	include <sys/endian.h>

#elif defined(__WINDOWS__)

#	include <winsock2.h>
#ifdef __MINGW32__
#	include <sys/param.h>
#endif

#	if BYTE_ORDER == LITTLE_ENDIAN

#		define htobe32(x) htonl(x)
#		define htole32(x) (x)
 
#		define htobe64(x) htonll(x)
#		define htole64(x) (x)

#	elif BYTE_ORDER == BIG_ENDIAN

		/* that would be xbox 360 */
#		define htobe32(x) (x)
#		define htole32(x) __builtin_bswap32(x)
 
#		define htobe64(x) (x)
#		define htole64(x) __builtin_bswap64(x)

#	else

#		error byte order not supported

#	endif

#	define __BYTE_ORDER    BYTE_ORDER
#	define __BIG_ENDIAN    BIG_ENDIAN
#	define __LITTLE_ENDIAN LITTLE_ENDIAN
#	define __PDP_ENDIAN    PDP_ENDIAN

#else

#	error platform not supported

#endif

#endif
