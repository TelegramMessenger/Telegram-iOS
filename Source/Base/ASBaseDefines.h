//
//  ASBaseDefines.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>

#define AS_EXTERN FOUNDATION_EXTERN
#define unowned __unsafe_unretained

/**
 * Hack to support building for iOS with Xcode 9. UIUserInterfaceStyle was previously tvOS-only,
 * and it was added to iOS 12. Xcode 9 (iOS 11 SDK) will flat-out refuse to build anything that
 * references this enum targeting iOS, even if it's guarded with the right availability macros,
 * because it thinks the entire platform isn't compatible with the enum.
 */
#if TARGET_OS_TV || (defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0)
#define AS_BUILD_UIUSERINTERFACESTYLE 1
#else
#define AS_BUILD_UIUSERINTERFACESTYLE 0
#endif

#ifdef __GNUC__
# define ASDISPLAYNODE_GNUC(major, minor) \
(__GNUC__ > (major) || (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#else
# define ASDISPLAYNODE_GNUC(major, minor) 0
#endif

#ifndef ASDISPLAYNODE_INLINE
# if defined (__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
#  define ASDISPLAYNODE_INLINE static inline
# elif defined (__MWERKS__) || defined (__cplusplus)
#  define ASDISPLAYNODE_INLINE static inline
# elif ASDISPLAYNODE_GNUC (3, 0)
#  define ASDISPLAYNODE_INLINE static __inline__ __attribute__ ((always_inline))
# else
#  define ASDISPLAYNODE_INLINE static
# endif
#endif

#ifndef ASDISPLAYNODE_WARN_DEPRECATED
# define ASDISPLAYNODE_WARN_DEPRECATED 1
#endif

#ifndef ASDISPLAYNODE_DEPRECATED
# if ASDISPLAYNODE_GNUC (3, 0) && ASDISPLAYNODE_WARN_DEPRECATED
#  define ASDISPLAYNODE_DEPRECATED __attribute__ ((deprecated))
# else
#  define ASDISPLAYNODE_DEPRECATED
# endif
#endif

#ifndef ASDISPLAYNODE_DEPRECATED_MSG
# if ASDISPLAYNODE_GNUC (3, 0) && ASDISPLAYNODE_WARN_DEPRECATED
#   define  ASDISPLAYNODE_DEPRECATED_MSG(msg) __deprecated_msg(msg)
# else
#   define  ASDISPLAYNODE_DEPRECATED_MSG(msg)
# endif
#endif

#ifndef AS_ENABLE_TIPS
#define AS_ENABLE_TIPS 0
#endif

/**
 * The event backtraces take a static 2KB of memory
 * and retain all objects present in all the registers
 * of the stack frames. The memory consumption impact
 * is too significant even to be enabled during general
 * development.
 */
#ifndef AS_SAVE_EVENT_BACKTRACES
# define AS_SAVE_EVENT_BACKTRACES 0
#endif

#ifndef __has_feature      // Optional.
#define __has_feature(x) 0 // Compatibility with non-clang compilers.
#endif

#ifndef __has_attribute      // Optional.
#define __has_attribute(x) 0 // Compatibility with non-clang compilers.
#endif

#ifndef NS_RETURNS_RETAINED
#if __has_feature(attribute_ns_returns_retained)
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
#else
#define NS_RETURNS_RETAINED
#endif
#endif

#ifndef CF_RETURNS_RETAINED
#if __has_feature(attribute_cf_returns_retained)
#define CF_RETURNS_RETAINED __attribute__((cf_returns_retained))
#else
#define CF_RETURNS_RETAINED
#endif
#endif

#ifndef ASDISPLAYNODE_REQUIRES_SUPER
#if __has_attribute(objc_requires_super)
#define ASDISPLAYNODE_REQUIRES_SUPER __attribute__((objc_requires_super))
#else
#define ASDISPLAYNODE_REQUIRES_SUPER
#endif
#endif

#ifndef AS_UNAVAILABLE
#if __has_attribute(unavailable)
#define AS_UNAVAILABLE(message) __attribute__((unavailable(message)))
#else
#define AS_UNAVAILABLE(message)
#endif
#endif

#ifndef AS_WARN_UNUSED_RESULT
#if __has_attribute(warn_unused_result)
#define AS_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#else
#define AS_WARN_UNUSED_RESULT
#endif
#endif

#define ASOVERLOADABLE __attribute__((overloadable))


#if __has_attribute(noescape)
#define AS_NOESCAPE __attribute__((noescape))
#else
#define AS_NOESCAPE
#endif

#if __has_attribute(objc_subclassing_restricted)
#define AS_SUBCLASSING_RESTRICTED __attribute__((objc_subclassing_restricted))
#else
#define AS_SUBCLASSING_RESTRICTED
#endif

#define ASCreateOnce(expr) ({ \
  static dispatch_once_t onceToken; \
  static __typeof__(expr) staticVar; \
  dispatch_once(&onceToken, ^{ \
    staticVar = expr; \
  }); \
  staticVar; \
})

/// Ensure that class is of certain kind
#define ASDynamicCast(x, c) ({ \
  id __val = x;\
  ((c *) ([__val isKindOfClass:[c class]] ? __val : nil));\
})

/// Ensure that class is of certain kind, assuming it is subclass restricted
#define ASDynamicCastStrict(x, c) ({ \
  id __val = x;\
  ((c *) ([__val class] == [c class] ? __val : nil));\
})

// Compare two primitives, assign if different. Returns whether the assignment happened.
#define ASCompareAssign(lvalue, newValue) ({  \
  BOOL result = (lvalue != newValue);         \
  if (result) { lvalue = newValue; }          \
  result;                                     \
})

#define ASCompareAssignObjects(lvalue, newValue) \
  ASCompareAssignCustom(lvalue, newValue, ASObjectIsEqual)

// e.g. ASCompareAssignCustom(_myInsets, insets, UIEdgeInsetsEqualToEdgeInsets)
#define ASCompareAssignCustom(lvalue, newValue, isequal) ({  \
  BOOL result = !(isequal(lvalue, newValue));                \
  if (result) { lvalue = newValue; }                         \
  result;                                                    \
})

#define ASCompareAssignCopy(lvalue, newValue) ({           \
  BOOL result = !ASObjectIsEqual(lvalue, newValue);        \
  if (result) { lvalue = [newValue copyWithZone:NULL]; }   \
  result;                                                  \
})

/**
 * Create a new set by mapping `collection` over `work`, ignoring nil.
 */
#define ASSetByFlatMapping(collection, decl, work) ({ \
  NSMutableSet *s = [[NSMutableSet alloc] init]; \
  for (decl in collection) {\
    id result = work; \
    if (result != nil) { \
      [s addObject:result]; \
    } \
  } \
  s; \
})

/**
 * Create a new ObjectPointerPersonality NSHashTable by mapping `collection` over `work`, ignoring nil.
 *
 * capacity: 0 is taken from +hashTableWithOptions.
 */
#define ASPointerTableByFlatMapping(collection, decl, work) ({ \
  NSHashTable *t = [[NSHashTable alloc] initWithOptions:NSHashTableObjectPointerPersonality capacity:0]; \
  for (decl in collection) {\
    id result = work; \
    if (result != nil) { \
      [t addObject:result]; \
    } \
  } \
  t; \
})

/**
 * Create a new array by mapping `collection` over `work`, ignoring nil.
 */
#define ASArrayByFlatMapping(collectionArg, decl, work) ({ \
  id __collection = collectionArg; \
  NSArray *__result; \
  if (__collection) { \
    id __buf[[__collection count]]; \
    NSUInteger __i = 0; \
    for (decl in __collection) {\
      if ((__buf[__i] = work)) { \
        __i++; \
      } \
    } \
    __result = [NSArray arrayByTransferring:__buf count:__i]; \
  } \
  __result; \
})

/**
 * Capture-and-clear a strong reference without the intervening retain/release pair.
 *
 * E.g. const auto localVar = ASTransferStrong(_myIvar);
 * Post-condition: localVar has the strong value from _myIvar and _myIvar is nil.
 * No retain/release is emitted when the optimizer is on.
 */
#define ASTransferStrong(lvalue) ({ \
  CFTypeRef *__rawPtr = (CFTypeRef *)(void *)(&(lvalue)); \
  CFTypeRef __cfValue = *__rawPtr; \
  *__rawPtr = NULL; \
  __typeof(lvalue) __result = (__bridge_transfer __typeof(lvalue))__cfValue; \
  __result; \
})
