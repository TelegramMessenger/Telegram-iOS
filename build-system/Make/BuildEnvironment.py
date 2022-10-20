import json
import os
import platform
import subprocess
import sys

def is_apple_silicon():
    if platform.processor() == 'arm':
        return True
    else:
        return False


def get_clean_env():
    clean_env = os.environ.copy()
    clean_env['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin'
    return clean_env


def resolve_executable(program):
    def is_executable(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    for path in get_clean_env()["PATH"].split(os.pathsep):
        executable_file = os.path.join(path, program)
        if is_executable(executable_file):
            return executable_file
    return None


def run_executable_with_output(path, arguments, decode=True, input=None, stderr_to_stdout=True, print_command=False, check_result=False):
    executable_path = resolve_executable(path)
    if executable_path is None:
        raise Exception('Could not resolve {} to a valid executable file'.format(path))

    stderr_assignment = subprocess.DEVNULL
    if stderr_to_stdout:
        stderr_assignment = subprocess.STDOUT

    if print_command:
        print('Running {} {}'.format(executable_path, arguments))

    process = subprocess.Popen(
        [executable_path] + arguments,
        stdout=subprocess.PIPE,
        stderr=stderr_assignment,
        stdin=subprocess.PIPE,
        env=get_clean_env()
    )
    if input is not None:
        output_data, _ = process.communicate(input=input)
    else:
        output_data, _ = process.communicate()

    output_string = output_data.decode('utf-8')

    if check_result:
        if process.returncode != 0:
            print('Command {} {} finished with non-zero return code and output:\n{}'.format(executable_path, arguments, output_string))
            sys.exit(1)

    if decode:
        return output_string
    else:
        return output_data


def call_executable(arguments, use_clean_environment=True, check_result=True):
    executable_path = resolve_executable(arguments[0])
    if executable_path is None:
        raise Exception('Could not resolve {} to a valid executable file'.format(arguments[0]))

    if use_clean_environment:
        resolved_env = get_clean_env()
    else:
        resolved_env = os.environ

    resolved_arguments = [executable_path] + arguments[1:]

    if check_result:
        subprocess.check_call(resolved_arguments, env=resolved_env)
    else:
        subprocess.call(resolved_arguments, env=resolved_env)


def check_run_system(command):
    if os.system(command) != 0:
        print('Command failed: {}'.format(command))
        sys.exit(1)


def get_bazel_version(bazel_path):
    command_result = run_executable_with_output(bazel_path, ['--version']).strip('\n')
    if not command_result.startswith('bazel '):
        raise Exception('{} is not a valid bazel binary'.format(bazel_path))
    command_result = command_result.replace('bazel ', '')
    return command_result


def get_xcode_version():
    xcode_path = run_executable_with_output('xcode-select', ['-p']).strip('\n')
    if not os.path.isdir(xcode_path):
        print('The path reported by \'xcode-select -p\' does not exist')
        exit(1)

    plist_path = '{}/../Info.plist'.format(xcode_path)

    info_plist_lines = run_executable_with_output('plutil', [
        '-p', plist_path
    ]).split('\n')

    pattern = 'CFBundleShortVersionString" => '
    for line in info_plist_lines:
        index = line.find(pattern)
        if index != -1:
            version = line[index + len(pattern):].strip('"')
            return version

    print('Could not parse the Xcode version from {}'.format(plist_path))
    exit(1)


class BuildEnvironmentVersions:
    def __init__(
            self,
            base_path
            ):
        configuration_path = os.path.join(base_path, 'versions.json')
        with open(configuration_path) as file:
            configuration_dict = json.load(file)
            if configuration_dict['app'] is None:
                raise Exception('Missing app version in {}'.format(configuration_path))
            else:
                self.app_version = configuration_dict['app']
            if configuration_dict['bazel'] is None:
                raise Exception('Missing bazel version in {}'.format(configuration_path))
            else:
                self.bazel_version = configuration_dict['bazel']
            if configuration_dict['xcode'] is None:
                raise Exception('Missing xcode version in {}'.format(configuration_path))
            else:
                self.xcode_version = configuration_dict['xcode']

class BuildEnvironment:
    def __init__(
            self,
            base_path,
            bazel_path,
            override_bazel_version,
            override_xcode_version
            ):
        self.base_path = os.path.expanduser(base_path)
        self.bazel_path = os.path.expanduser(bazel_path)

        versions = BuildEnvironmentVersions(base_path=self.base_path)

        actual_bazel_version = get_bazel_version(self.bazel_path)
        if actual_bazel_version != versions.bazel_version:
            if override_bazel_version:
                print('Overriding the required bazel version {} with {} as reported by {}'.format(
                    versions.bazel_version, actual_bazel_version, self.bazel_path))
                self.bazel_version = actual_bazel_version
            else:
                print('Required bazel version is "{}", but "{}"" is reported by {}'.format(
                    versions.bazel_version, actual_bazel_version, self.bazel_path))
                exit(1)

        actual_xcode_version = get_xcode_version()
        if actual_xcode_version != versions.xcode_version:
            if override_xcode_version:
                print('Overriding the required Xcode version {} with {} as reported by \'xcode-select -p\''.format(
                    versions.xcode_version, actual_xcode_version, self.bazel_path))
                versions.xcode_version = actual_xcode_version
            else:
                print('Required Xcode version is {}, but {} is reported by \'xcode-select -p\''.format(
                    versions.xcode_version, actual_xcode_version, self.bazel_path))
                exit(1)

        self.app_version = versions.app_version
        self.xcode_version = versions.xcode_version
        self.bazel_version = versions.bazel_version
