import json
import os
import shutil

from BuildEnvironment import is_apple_silicon, call_executable, BuildEnvironment


def remove_directory(path):
    if os.path.isdir(path):
        shutil.rmtree(path)


def generate(build_environment: BuildEnvironment, disable_extensions, disable_provisioning_profiles, generate_dsym, configuration_path, bazel_app_arguments, target_name):
    project_path = os.path.join(build_environment.base_path, 'build-input/gen/project')

    if '/' in target_name:
        app_target_spec = target_name.split('/')[0] + '/' + target_name.split('/')[1] + ':' + target_name.split('/')[1]
        app_target = target_name
        app_target_clean = app_target.replace('/', '_')
    else:
        app_target_spec = '{target}:{target}'.format(target=target_name)
        app_target = target_name
        app_target_clean = app_target.replace('/', '_')

    os.makedirs(project_path, exist_ok=True)
    remove_directory('{}/Tulsi.app'.format(project_path))
    remove_directory('{project}/{target}.tulsiproj'.format(project=project_path, target=app_target_clean))

    tulsi_path = os.path.join(project_path, 'Tulsi.app/Contents/MacOS/Tulsi')

    tulsi_build_bazel_path = build_environment.bazel_path

    current_dir = os.getcwd()
    os.chdir(os.path.join(build_environment.base_path, 'build-system/tulsi'))

    tulsi_build_command = []
    tulsi_build_command += [tulsi_build_bazel_path]
    tulsi_build_command += ['build', '//:tulsi']
    if is_apple_silicon():
        tulsi_build_command += ['--macos_cpus=arm64']
    tulsi_build_command += ['--xcode_version={}'.format(build_environment.xcode_version)]
    tulsi_build_command += ['--use_top_level_targets_for_symlinks']
    tulsi_build_command += ['--verbose_failures']
    tulsi_build_command += ['--swiftcopt=-whole-module-optimization']

    call_executable(tulsi_build_command)

    os.chdir(current_dir)

    bazel_wrapper_path = os.path.abspath('build-input/gen/project/bazel')

    bazel_wrapper_arguments = []
    bazel_wrapper_arguments += ['--override_repository=build_configuration={}'.format(configuration_path)]

    with open(bazel_wrapper_path, 'wb') as bazel_wrapper:
        bazel_wrapper.write('''#!/bin/sh
{bazel} "$@" {arguments}
'''.format(
            bazel=build_environment.bazel_path,
            arguments=' '.join(bazel_wrapper_arguments)
        ).encode('utf-8'))

    call_executable(['chmod', '+x', bazel_wrapper_path])

    call_executable([
        'unzip', '-oq',
        'build-system/tulsi/bazel-bin/tulsi.zip',
        '-d', project_path
    ])

    user_defaults_path = os.path.expanduser('~/Library/Preferences/com.google.Tulsi.plist')
    if os.path.isfile(user_defaults_path):
        os.unlink(user_defaults_path)

    with open(user_defaults_path, 'wb') as user_defaults:
        user_defaults.write('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>defaultBazelURL</key>
        <string>{}</string>
</dict>
</plist>
'''.format(bazel_wrapper_path).encode('utf-8'))

    bazel_build_arguments = []
    bazel_build_arguments += ['--override_repository=build_configuration={}'.format(configuration_path)]
    if disable_extensions:
        bazel_build_arguments += ['--//{}:disableExtensions'.format(app_target)]
    if disable_provisioning_profiles:
        bazel_build_arguments += ['--//{}:disableProvisioningProfiles'.format(app_target)]
    if generate_dsym:
        bazel_build_arguments += ['--apple_generate_dsym']
    bazel_build_arguments += ['--//{}:disableStripping'.format('Telegram')]
    bazel_build_arguments += ['--strip=never']

    call_executable([
        tulsi_path,
        '--',
        '--verbose',
        '--create-tulsiproj', app_target_clean,
        '--workspaceroot', './',
        '--bazel', bazel_wrapper_path,
        '--outputfolder', project_path,
        '--target', '{target_spec}'.format(target_spec=app_target_spec),
        '--build-options', ' '.join(bazel_build_arguments)
    ])

    additional_arguments = []
    additional_arguments += ['--override_repository=build_configuration={}'.format(configuration_path)]
    additional_arguments += bazel_app_arguments
    if disable_extensions:
        additional_arguments += ['--//{}:disableExtensions'.format(app_target)]

    additional_arguments_string = ' '.join(additional_arguments)

    tulsi_config_path = 'build-input/gen/project/{target}.tulsiproj/Configs/{target}.tulsigen'.format(target=app_target_clean)
    with open(tulsi_config_path, 'rb') as tulsi_config:
        tulsi_config_json = json.load(tulsi_config)
    for category in ['BazelBuildOptionsDebug', 'BazelBuildOptionsRelease']:
        tulsi_config_json['optionSet'][category]['p'] += ' {}'.format(additional_arguments_string)
    tulsi_config_json['sourceFilters'] = [
        '{}/...'.format(app_target),
        'submodules/...',
        'third-party/...'
    ]
    with open(tulsi_config_path, 'wb') as tulsi_config:
        tulsi_config.write(json.dumps(tulsi_config_json, indent=2).encode('utf-8'))

    call_executable([
        tulsi_path,
        '--',
        '--verbose',
        '--genconfig', '{project}/{target}.tulsiproj:{target}'.format(project=project_path, target=app_target_clean),
        '--bazel', bazel_wrapper_path,
        '--outputfolder', project_path,
        '--no-open-xcode'
    ])

    xcodeproj_path = '{project}/{target}.xcodeproj'.format(project=project_path, target=app_target_clean)

    call_executable(['open', xcodeproj_path])
