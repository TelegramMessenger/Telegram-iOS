//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/rlimit.h"

#include "td/utils/port/config.h"

#include "td/utils/misc.h"

#if TD_PORT_POSIX
#include <sys/resource.h>
#include <sys/time.h>
#include <sys/types.h>
#endif

namespace td {

#if TD_PORT_POSIX
static int get_resource(ResourceLimitType type) {
  switch (type) {
    case ResourceLimitType::NoFile:
      return RLIMIT_NOFILE;
    default:
      UNREACHABLE();
      return -1;
  }
}
#endif

Status set_resource_limit(ResourceLimitType type, uint64 value, uint64 max_value) {
#if TD_PORT_POSIX
  if (max_value != 0 && value > max_value) {
    return Status::Error("New resource limit value must not be bigger than max_value");
  }

  int resource = get_resource(type);

  rlimit rlim;
  if (getrlimit(resource, &rlim) == -1) {
    return OS_ERROR("Failed to get current resource limit");
  }

  TRY_RESULT(new_value, narrow_cast_safe<rlim_t>(value));
  TRY_RESULT(new_max_value, narrow_cast_safe<rlim_t>(max_value));
  if (new_max_value) {
    rlim.rlim_max = new_max_value;
  } else if (rlim.rlim_max < new_value) {
    rlim.rlim_max = new_value;
  }
  rlim.rlim_cur = new_value;

  if (setrlimit(resource, &rlim) < 0) {
    return OS_ERROR("Failed to set resource limit");
  }
  return Status::OK();
#elif TD_PORT_WINDOWS
  return Status::OK();  // Windows has no limits
#endif
}

Status set_maximize_resource_limit(ResourceLimitType type, uint64 value) {
#if TD_PORT_POSIX
  int resource = get_resource(type);

  rlimit rlim;
  if (getrlimit(resource, &rlim) == -1) {
    return OS_ERROR("Failed to get current resource limit");
  }

  TRY_RESULT(new_value, narrow_cast_safe<rlim_t>(value));
  if (rlim.rlim_max < new_value) {
    // trying to increase rlim_max
    rlimit new_rlim;
    new_rlim.rlim_cur = new_value;
    new_rlim.rlim_max = new_value;
    if (setrlimit(resource, &new_rlim) >= 0) {
      return Status::OK();
    }

    // do not increase rlim_max if have no rights
    new_value = rlim.rlim_max;
  }
  rlim.rlim_cur = new_value;

  if (setrlimit(resource, &rlim) < 0) {
    return OS_ERROR("Failed to set resource limit");
  }
  return Status::OK();
#elif TD_PORT_WINDOWS
  return Status::OK();  // Windows has no limits
#endif
}

}  // namespace td
