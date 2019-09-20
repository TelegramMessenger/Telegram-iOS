#include "user.h"
#if TD_LINUX
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>
#endif

namespace td {

#if TD_LINUX
td::Status change_user(td::Slice user) {
  struct passwd *pw;
  if (getuid() != 0 || geteuid() != 0) {
    return td::Status::PosixError(errno, "cannot setuid() as not root");
  }
  if ((pw = getpwnam(user.str().c_str())) == 0) {
    return td::Status::PosixError(errno, PSTRING() << "bad user '" << user << "'");
  }
  gid_t gid = pw->pw_gid;
  if (setgroups(1, &gid) < 0) {
    return td::Status::PosixError(errno, "failed to clear supplementary groups list");
  }
  if (initgroups(user.str().c_str(), gid) != 0) {
    return td::Status::PosixError(errno, "failed to load groups of user");
  }
  if (setgid(pw->pw_gid) < 0) {
    return td::Status::PosixError(errno, "failed to setgid()");
  }
  if (setuid(pw->pw_uid) < 0) {
    return td::Status::PosixError(errno, "failed to setuid()");
  }
  return td::Status::OK();
}
#else
td::Status change_user(td::Slice username) {
  return td::Status::Error("not implemented");
}
#endif

}  // namespace td
