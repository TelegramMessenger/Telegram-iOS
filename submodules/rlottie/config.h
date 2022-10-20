#ifndef CONFIG_H
#define CONFIG_H

// enable threading
//#define LOTTIE_THREAD_SUPPORT

#ifndef LOTTIE_THREAD_SAFE
#define LOTTIE_THREAD_SAFE
#endif

//enable logging
//#define LOTTIE_LOGGING_SUPPORT

//enable module building of image loader
//#define LOTTIE_IMAGE_MODULE_SUPPORT

//enable lottie model caching
//#define LOTTIE_CACHE_SUPPORT

// disable image loader
#ifndef LOTTIE_IMAGE_MODULE_DISABLED
#define LOTTIE_IMAGE_MODULE_DISABLED
#endif

#endif  // CONFIG_H
