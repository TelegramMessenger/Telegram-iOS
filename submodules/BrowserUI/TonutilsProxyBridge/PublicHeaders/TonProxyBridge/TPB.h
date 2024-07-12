//
//  Created by Adam Stragner
//

#ifndef TPB_h
#define TPB_h

#import <Foundation/Foundation.h>

// _TPB_EXPORT
#if !defined(_TPB_EXPORT)
#   if defined(__cplusplus)
#       define _TPB_EXPORT extern "C"
#   else
#       define _TPB_EXPORT extern
#   endif
#endif /* _TPB_EXPORT */

// _TPB_SWIFT_ERROR
#if !defined(_TPB_SWIFT_ERROR)
#   if __OBJC__ && __has_attribute(swift_error)
#       define _TPB_SWIFT_ERROR __attribute__((swift_error(nonnull_error)));
#   else
#       abort();
#   endif
#endif /* _TPB_SWIFT_ERROR */

// _TPB_EXTERN
#if !defined(_TPB_EXTERN)
#   if defined(__cplusplus)
#       define _TPB_EXTERN extern "C" __attribute__((visibility ("default")))
#   else
#       define _TPB_EXTERN extern __attribute__((visibility ("default")))
#   endif
#endif /* _TPB_EXTERN */

#define TPB_EXPORT           _TPB_EXPORT
#define TPB_EXTERN           _TPB_EXTERN
#define TPB_SWIFT_ERROR      _TPB_SWIFT_ERROR
#define TPB_STATIC_INLINE    static inline

#endif /* TPB_h */
