#ifndef VectorsCocoa_h
#define VectorsCocoa_h

#ifdef __cplusplus

#import <QuartzCore/QuartzCore.h>

namespace lottie {

::CATransform3D nativeTransform(CATransform3D const &value);
CATransform3D fromNativeTransform(::CATransform3D const &value);

}

#endif

#endif /* VectorsCocoa_h */
