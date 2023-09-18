#!/usr/bin/env python3
#
# Copyright 2021 Google Inc.
#
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os
import subprocess
import sys
import tempfile


def call(cmd):
  print("Executing: " + " ".join(cmd))
  subprocess.check_call(cmd)


def main():
  build_or_test = sys.argv[1]
  assert build_or_test in ["build", "test"]

  local_or_rbe = sys.argv[2]
  assert local_or_rbe in ["local", "rbe"]

  target = sys.argv[3]
  assert target in ["android-arm", "android-arm64", "linux", "windows"]

  print("Hello from {platform} in {cwd}!".format(platform=sys.platform,
                                                 cwd=os.getcwd()))

  # Create a temporary directory for the Bazel cache.
  #
  # We cannot use the default Bazel cache location ($HOME/.cache/bazel) because:
  #
  #  - The cache can be large (>10G).
  #  - Swarming bots have limited storage space on the root partition (15G).
  #  - Because the above, the Bazel build fails with a "no space left on
  #    device" error.
  #  - The Bazel cache under $HOME/.cache/bazel lingers after the tryjob
  #    completes, causing the Swarming bot to be quarantined due to low disk
  #    space.
  #  - Generally, it's considered poor hygiene to leave a bot in a different
  #    state.
  #
  # The temporary directory created by the below function call lives under
  # /mnt/pd0, which has significantly more storage space, and will be wiped
  # after the tryjob completes.
  #
  # Reference: https://docs.bazel.build/versions/master/output_directories.html#current-layout.
  with tempfile.TemporaryDirectory(prefix="bazel-cache-",
                                   dir=os.environ["TMPDIR"]) as cache_dir:
    def bazel(args):
      cmd = ["C:\\b\\s\\w\\ir\\bazelisk\\bazelisk.exe"] if target == "windows" \
            else ["bazelisk", "--output_user_root=" + cache_dir]
      print("Running", cmd)
      call(cmd + args)

    try:
      # Print the Bazel version.
      bazel(["version"])

      # Compute the Bazel configuration to use.
      config = target
      if local_or_rbe == "rbe":
        config += "-rbe"

      # Run the requested Bazel command.
      os.chdir("skcms")
      bazel([build_or_test, "//...", "--config=" + config])

    finally:
      # Kill the Bazel server, so as not to leave any children processes
      # outliving the Swarming task.
      bazel(["shutdown"])

if __name__ == "__main__":
  main()
