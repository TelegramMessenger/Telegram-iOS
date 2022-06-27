import os
import stat
import sys

from BuildEnvironment import is_apple_silicon, resolve_executable, call_executable, BuildEnvironmentVersions

def locate_bazel(base_path):
    build_input_dir = '{}/build-input'.format(base_path)
    if not os.path.isdir(build_input_dir):
        os.mkdir(build_input_dir)

    versions = BuildEnvironmentVersions(base_path=os.getcwd())
    if is_apple_silicon():
        arch = 'darwin-arm64'
    else:
        arch = 'darwin-x86_64'
    bazel_name = 'bazel-{version}-{arch}'.format(version=versions.bazel_version, arch=arch)
    bazel_path = '{}/build-input/{}'.format(base_path, bazel_name)

    if not os.path.isfile(bazel_path):
        call_executable([
            'curl',
            '-L',
            'https://github.com/bazelbuild/bazel/releases/download/{version}/{name}'.format(
                version=versions.bazel_version,
                name=bazel_name
            ),
            '--output',
            bazel_path
        ])

    if not os.access(bazel_path, os.X_OK):
        st = os.stat(bazel_path)
        os.chmod(bazel_path, st.st_mode | stat.S_IEXEC)

    return bazel_path
