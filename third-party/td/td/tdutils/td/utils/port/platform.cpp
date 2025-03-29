//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/platform.h"

char disable_linker_warning_about_empty_file_platform_cpp TD_UNUSED;

#if !TD_MSVC

#if TD_DARWIN_UNKNOWN
#warning "Probably unsupported Apple operating system. Feel free to try to compile"
#endif

#if TD_UNIX_UNKNOWN
#warning "Probably unsupported Unix operating system. Feel free to try to compile"
#endif

#if TD_COMPILER_UNKNOWN
#warning "Probably unsupported compiler. Feel free to try to compile"
#endif

#endif
