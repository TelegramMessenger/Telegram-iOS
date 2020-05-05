#!/bin/sh

PATCH=$(cat <<-END
--- a/rtc_base/BUILD.gn
+++ b/rtc_base/BUILD.gn
@@ -23,7 +23,11 @@ if (!rtc_build_ssl) {
   config("external_ssl_library") {
     assert(rtc_ssl_root != "",
            "You must specify rtc_ssl_root when rtc_build_ssl==0.")
-    include_dirs = [ rtc_ssl_root ]
+    include_dirs = [ "\$rtc_ssl_root/include" ]
+    libs = [
+      "\$rtc_ssl_root/libssl.a",
+      "\$rtc_ssl_root/libcrypto.a"
+    ]
   }
 }

--- a/third_party/usrsctp/BUILD.gn
+++ b/third_party/usrsctp/BUILD.gn
@@ -3,6 +3,7 @@
 # found in the LICENSE file.

 import("//build/toolchain/toolchain.gni")
+import("//webrtc.gni")

 config("usrsctp_config") {
   include_dirs = [
@@ -140,7 +141,9 @@ static_library("usrsctp") {
   if (is_fuchsia) {
     defines += [ "__Userspace_os_Fuchsia" ]
   }
-  deps = [
-    "//third_party/boringssl",
-  ]
+  if (rtc_build_ssl) {
+    deps += [ "//third_party/boringssl" ]
+  } else {
+    configs += [ "//rtc_base:external_ssl_library" ]
+  }
 }

--- a/third_party/libsrtp/BUILD.gn
+++ b/third_party/libsrtp/BUILD.gn
@@ -3,6 +3,7 @@
 # found in the LICENSE file.

 import("//testing/test.gni")
+import("//webrtc.gni")

 declare_args() {
   # Tests may not be appropriate for some build environments, e.g. Windows.
@@ -114,9 +115,11 @@ static_library("libsrtp") {
     "srtp/ekt.c",
     "srtp/srtp.c",
   ]
-  public_deps = [
-    "//third_party/boringssl:boringssl",
-  ]
+  if (rtc_build_ssl) {
+    public_deps = [ "//third_party/boringssl" ]
+  } else {
+    configs += [ "//rtc_base:external_ssl_library" ]
+  }
 }

 if (build_libsrtp_tests) {
END
)

echo "$PATCH" | patch -p1
