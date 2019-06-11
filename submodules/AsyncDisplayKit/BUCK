load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'combined_config', 'configs_with_config')
load('//tools:buck_defs.bzl', 'SHARED_CONFIGS', 'EXTENSION_LIB_SPECIFIC_CONFIG')

COMMON_PREPROCESSOR_FLAGS = [
  '-fobjc-arc',
  '-DMINIMAL_ASDK',
  '-fno-exceptions',
  '-fno-objc-arc-exceptions'
]

COMMON_LANG_PREPROCESSOR_FLAGS = {
  'C': ['-std=gnu99'],
  'CXX': ['-std=c++11', '-stdlib=libc++'],
  'OBJCXX': ['-std=c++11', '-stdlib=libc++'],
}

COMMON_LINKER_FLAGS = ['-ObjC++']

ASYNCDISPLAYKIT_EXPORTED_HEADERS = glob([
  'Source/*.h',
  'Source/Details/**/*.h',
  'Source/Layout/*.h',
  'Source/Base/*.h',
  'Source/Debug/AsyncDisplayKit+Debug.h',
  # Most TextKit components are not public because the C++ content
  # in the headers will cause build errors when using
  # `use_frameworks!` on 0.39.0 & Swift 2.1.
  # See https://github.com/facebook/AsyncDisplayKit/issues/1153
  'Source/TextKit/ASTextNodeTypes.h',
  'Source/TextKit/ASTextKitComponents.h'
])

ASYNCDISPLAYKIT_PRIVATE_HEADERS = glob([
    'Source/**/*.h'
  ],
  exclude = ASYNCDISPLAYKIT_EXPORTED_HEADERS,
)

apple_library(
    name = "AsyncDisplayKit",
    header_path_prefix = 'AsyncDisplayKit',
    exported_headers = ASYNCDISPLAYKIT_EXPORTED_HEADERS,
    headers = ASYNCDISPLAYKIT_PRIVATE_HEADERS,
    srcs = glob([
      'Source/**/*.m',
      'Source/**/*.mm',
      'Source/Base/*.m'
    ]),
    configs = configs_with_config(combined_config([SHARED_CONFIGS, EXTENSION_LIB_SPECIFIC_CONFIG])),
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
    lang_preprocessor_flags = COMMON_LANG_PREPROCESSOR_FLAGS,
    linker_flags = COMMON_LINKER_FLAGS,
    modular = True,
    compiler_flags = ['-w'],
    visibility = ["PUBLIC"],
    frameworks = [
      '$SDKROOT/System/Library/Frameworks/Foundation.framework',
      '$SDKROOT/System/Library/Frameworks/UIKit.framework',
      '$SDKROOT/System/Library/Frameworks/QuartzCore.framework',
      '$SDKROOT/System/Library/Frameworks/CoreMedia.framework',
      '$SDKROOT/System/Library/Frameworks/CoreText.framework',
      '$SDKROOT/System/Library/Frameworks/CoreGraphics.framework',
    ]
)
