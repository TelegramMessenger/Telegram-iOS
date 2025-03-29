//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/uname.h"

#include "td/utils/port/config.h"

#include "td/utils/common.h"
#include "td/utils/filesystem.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Stat.h"
#include "td/utils/SliceBuilder.h"

#if TD_PORT_POSIX

#include <cstring>

#if TD_ANDROID
#include <sys/system_properties.h>
#elif TD_EMSCRIPTEN
#include <cstdlib>

#include <emscripten.h>
#else
#if TD_DARWIN
#include <sys/sysctl.h>
#include <sys/types.h>
#endif
#include <sys/utsname.h>
#endif

#endif

namespace td {

#if TD_DARWIN || TD_LINUX
static string read_os_name(CSlice os_version_file_path, CSlice prefix, CSlice suffix) {
  auto r_stat = stat(os_version_file_path);
  if (r_stat.is_ok() && r_stat.ok().is_reg_ && r_stat.ok().size_ < (1 << 16)) {
    auto r_file = read_file_str(os_version_file_path, r_stat.ok().size_);
    if (r_file.is_ok()) {
      auto begin_pos = r_file.ok().find(prefix.c_str());
      if (begin_pos != string::npos) {
        begin_pos += prefix.size();
        auto end_pos = r_file.ok().find(suffix.c_str(), begin_pos);
        if (end_pos != string::npos) {
          auto os_version = trim(r_file.ok().substr(begin_pos, end_pos - begin_pos));
          if (os_version.find('\n') == string::npos) {
            return os_version;
          }
        }
      }
    }
  }
  return string();
}
#endif

Slice get_operating_system_version() {
  static string result = []() -> string {
#if TD_DARWIN
    char version[256];
    size_t size = sizeof(version);
    string os_version;
    if (sysctlbyname("kern.osproductversion", version, &size, nullptr, 0) == 0) {
      os_version = trim(string(version, size));
    }
    if (os_version.empty()) {
      os_version = read_os_name("/System/Library/CoreServices/SystemVersion.plist",
                                "<key>ProductUserVisibleVersion</key>\n\t<string>", "</string>\n");
    }
    if (!os_version.empty()) {
      os_version = " " + os_version;
    }

#if TD_DARWIN_IOS
    return "iOS" + os_version;
#elif TD_DARWIN_TV_OS
    return "tvOS" + os_version;
#elif TD_DARWIN_VISION_OS
    return "visionOS" + os_version;
#elif TD_DARWIN_WATCH_OS
    return "watchOS" + os_version;
#elif TD_DARWIN_MAC
    return "macOS" + os_version;
#else
    return "Darwin" + os_version;
#endif
#elif TD_PORT_POSIX
#if TD_ANDROID
    char version[PROP_VALUE_MAX + 1];
    int length = __system_property_get("ro.build.version.release", version);
    if (length > 0) {
      return "Android " + string(version, length);
    }
#elif TD_EMSCRIPTEN
    // clang-format off
    char *os_name_js = (char*)EM_ASM_INT(({
      function detectOsName() {
        if (typeof process === 'object' && typeof process.platform === 'string') { // Node.js
           switch (process.platform) {
             case 'aix':
               return 'IBM AIX';
             case 'android':
               return 'Android';
             case 'darwin':
               return 'macOS';
             case 'freebsd':
               return 'FreeBSD';
             case 'linux':
               return 'Linux';
             case 'openbsd':
               return 'OpenBSD';
             case 'sunos':
               return 'SunOS';
             case 'win32':
               return 'Windows';
             case 'darwin':
               return 'macOS';
             default:
               return 'Node.js';
          }
        }

        var userAgent = 'Unknown';
        if (typeof window === 'object') { // Web
          userAgent = window.navigator.userAgent;
        } else if (typeof importScripts === 'function') { // Web Worker
          userAgent = navigator.userAgent;
        }

        var match = /(Mac OS|Mac OS X|MacPPC|MacIntel|Mac_PowerPC|Macintosh) ([._0-9]+)/.exec(userAgent);
        if (match !== null) {
          return 'macOS ' + match[2].replace('_', '.');
        }

        match = /Android [._0-9]+/.exec(userAgent);
        if (match !== null) {
          return match[0].replace('_', '.');
        }

        if (/(iPhone|iPad|iPod)/.test(userAgent)) {
          match = /OS ([._0-9]+)/.exec(userAgent);
          if (match !== null) {
            return 'iOS ' + match[1].replace('_', '.');
          }
          return 'iOS';
        }

        var clientStrings = [
          {s:'Windows 11', r:/(Windows 11|Windows NT 11)/},
          // there is no way to distinguish Windows 10 from newer versions, so report it as just Windows.
          // {s:'Windows 10 or later', r:/(Windows 10|Windows NT 10)/},
          {s:'Windows 8.1', r:/(Windows 8.1|Windows NT 6.3)/},
          {s:'Windows 8', r:/(Windows 8|Windows NT 6.2)/},
          {s:'Windows 7', r:/(Windows 7|Windows NT 6.1)/},
          {s:'Windows Vista', r:/Windows NT 6.0/},
          {s:'Windows Server 2003', r:/Windows NT 5.2/},
          {s:'Windows XP', r:/(Windows XP|Windows NT 5.1)/},
          {s:'Windows', r:/Windows/},
          {s:'Android', r:/Android/},
          {s:'FreeBSD', r:/FreeBSD/},
          {s:'OpenBSD', r:/OpenBSD/},
          {s:'Chrome OS', r:/CrOS/},
          {s:'Linux', r:/(Linux|X11)/},
          {s:'macOS', r:/(Mac OS|MacPPC|MacIntel|Mac_PowerPC|Macintosh)/},
          {s:'QNX', r:/QNX/},
          {s:'BeOS', r:/BeOS/}
        ];
        for (var id in clientStrings) {
          var cs = clientStrings[id];
          if (cs.r.test(userAgent)) {
            return cs.s;
          }
        }
        return 'Emscripten';
      }

      var os_name = detectOsName();
      var length = lengthBytesUTF8(os_name) + 1;
      var result = _malloc(length);
      stringToUTF8(os_name, result, length);
      return result;
    }));
    // clang-format on
    string os_name(os_name_js);
    std::free(os_name_js);

    return os_name;
#else
#if TD_LINUX
    auto os_name = read_os_name("/etc/os-release", "PRETTY_NAME=\"", "\"\n");
    if (!os_name.empty()) {
      return os_name;
    }
#endif

    struct utsname name;
    int err = uname(&name);
    if (err == 0) {
      auto os_name = trim(PSTRING() << Slice(name.sysname, std::strlen(name.sysname)) << " "
                                    << Slice(name.release, std::strlen(name.release)));
      if (!os_name.empty()) {
        return os_name;
      }
    }
#endif
    LOG(ERROR) << "Failed to identify OS name; use generic one";

#if TD_ANDROID
    return "Android";
#elif TD_TIZEN
    return "Tizen";
#elif TD_LINUX
    return "Linux";
#elif TD_FREEBSD
    return "FreeBSD";
#elif TD_OPENBSD
    return "OpenBSD";
#elif TD_NETBSD
    return "NetBSD";
#elif TD_CYGWIN
    return "Cygwin";
#else
    return "Unix";
#endif

#else

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
    auto handle = GetModuleHandle(L"ntdll.dll");
    if (handle != nullptr) {
      using RtlGetVersionPtr = LONG(WINAPI *)(_Out_ PRTL_OSVERSIONINFOEXW);
      RtlGetVersionPtr RtlGetVersion = reinterpret_cast<RtlGetVersionPtr>(GetProcAddress(handle, "RtlGetVersion"));
      if (RtlGetVersion != nullptr) {
        RTL_OSVERSIONINFOEXW os_version_info = {};
        os_version_info.dwOSVersionInfoSize = sizeof(os_version_info);
        if (RtlGetVersion(&os_version_info) == 0) {
          auto major = os_version_info.dwMajorVersion;
          auto minor = os_version_info.dwMinorVersion;
          bool is_server = os_version_info.wProductType != VER_NT_WORKSTATION;

          if (major == 10) {
            if (is_server) {
              if (os_version_info.dwBuildNumber >= 20201) {
                // https://techcommunity.microsoft.com/t5/windows-server-insiders/announcing/m-p/1614436
                return "Windows Server 2022";
              }
              if (os_version_info.dwBuildNumber >= 17623) {
                // https://techcommunity.microsoft.com/t5/windows-server-insiders/announcing/m-p/173715
                return "Windows Server 2019";
              }
              return "Windows Server 2016";
            }
            if (os_version_info.dwBuildNumber >= 21900) {  // build numbers between 21391 and 21999 aren't used
              return "Windows 11";
            }
            return "Windows 10";
          }
          if (major == 6 && minor == 3) {
            return is_server ? "Windows Server 2012 R2" : "Windows 8.1";
          }
          if (major == 6 && minor == 2) {
            return is_server ? "Windows Server 2012" : "Windows 8";
          }
          if (major == 6 && minor == 1) {
            return is_server ? "Windows Server 2008 R2" : "Windows 7";
          }
          if (major == 6 && minor == 0) {
            return is_server ? "Windows Server 2008" : "Windows Vista";
          }
          return is_server ? "Windows Server" : "Windows";
        }
      }
    }
#elif TD_WINRT
    return "Windows 10";
#endif

    LOG(ERROR) << "Failed to identify OS name; use generic one";
    return "Windows";
#endif
  }();
  return result;
}

}  // namespace td
