
#ifndef TONLIBJSON_EXPORT_H
#define TONLIBJSON_EXPORT_H

#ifdef TONLIBJSON_STATIC_DEFINE
#  define TONLIBJSON_EXPORT
#  define TONLIBJSON_NO_EXPORT
#else
#  ifndef TONLIBJSON_EXPORT
#    ifdef tonlibjson_EXPORTS
        /* We are building this library */
#      define TONLIBJSON_EXPORT __attribute__((visibility("default")))
#    else
        /* We are using this library */
#      define TONLIBJSON_EXPORT __attribute__((visibility("default")))
#    endif
#  endif

#  ifndef TONLIBJSON_NO_EXPORT
#    define TONLIBJSON_NO_EXPORT __attribute__((visibility("hidden")))
#  endif
#endif

#ifndef TONLIBJSON_DEPRECATED
#  define TONLIBJSON_DEPRECATED __attribute__ ((__deprecated__))
#endif

#ifndef TONLIBJSON_DEPRECATED_EXPORT
#  define TONLIBJSON_DEPRECATED_EXPORT TONLIBJSON_EXPORT TONLIBJSON_DEPRECATED
#endif

#ifndef TONLIBJSON_DEPRECATED_NO_EXPORT
#  define TONLIBJSON_DEPRECATED_NO_EXPORT TONLIBJSON_NO_EXPORT TONLIBJSON_DEPRECATED
#endif

#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef TONLIBJSON_NO_DEPRECATED
#    define TONLIBJSON_NO_DEPRECATED
#  endif
#endif

#endif /* TONLIBJSON_EXPORT_H */
