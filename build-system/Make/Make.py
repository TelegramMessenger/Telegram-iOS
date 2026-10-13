#!/bin/python3

import argparse
import os
import shlex
import sys
import tempfile
import subprocess
import shutil
import glob

from BuildEnvironment import resolve_executable, call_executable, run_executable_with_output, BuildEnvironmentVersions, BuildEnvironment
from ProjectGeneration import generate
from BazelLocation import locate_bazel
from BuildConfiguration import CodesigningSource, GitCodesigningSource, DirectoryCodesigningSource, XcodeManagedCodesigningSource, BuildConfiguration, build_configuration_from_json
import RemoteBuild
import TartBuild
import GenerateProfiles


class ResolvedCodesigningData:
    def __init__(self, aps_environment, use_xcode_managed_codesigning):
        self.aps_environment = aps_environment
        self.use_xcode_managed_codesigning = use_xcode_managed_codesigning


class BazelCommandLine:
    def __init__(self, bazel, override_bazel_version, override_xcode_version, bazel_user_root):
        self.build_environment = BuildEnvironment(
            base_path=os.getcwd(),
            bazel_path=bazel,
            override_bazel_version=override_bazel_version,
            override_xcode_version=override_xcode_version
        )
        self.bazel = bazel
        self.bazel_user_root = bazel_user_root
        self.lock = False
        self.remote_cache = None
        self.cache_dir = None
        self.additional_args = None
        self.build_number = None
        self.configuration_args = None
        self.split_submodules = False
        self.custom_target = None
        self.continue_on_error = False
        self.show_actions = False
        self.enable_sandbox = False
        self.disable_provisioning_profiles = False
        self.profile_swift = False
        self.embed_watch_app = False
        self.watch_api_id = None
        self.watch_api_hash = None
        self.watch_signing_identity = None
        self.watch_provisioning_profile = None

        self.common_args = [
            # https://docs.bazel.build/versions/master/command-line-reference.html
            # Ask bazel to print the actual resolved command line options.
            '--announce_rc',

            # https://github.com/bazelbuild/rules_swift
            # If enabled, Swift compilation actions will use the same global Clang module
            # cache used by Objective-C compilation actions. This is disabled by default
            # because under some circumstances Clang module cache corruption can cause the
            # Swift compiler to crash (sometimes when switching configurations or syncing a
            # repository), but disabling it also causes a noticeable build time regression
            # so it can be explicitly re-enabled by users who are not affected by those
            # crashes.
            '--features=swift.use_global_module_cache',

            # https://docs.bazel.build/versions/master/command-line-reference.html
            # Print the subcommand details in case of failure.
            '--verbose_failures',

            # Asynchronously upload cache artifacts
            '--remote_cache_async',
        ]

        self.common_build_args = [
        ]

        num_threads = max(os.cpu_count() - 2, 2)
        self.common_debug_args = [
            '--@build_bazel_rules_swift//swift:copt="-j"',
            f'--@build_bazel_rules_swift//swift:copt="{num_threads}"',
        ]

        self.common_release_args = [
            # Enable cross-crate link-time optimization for Rust targets.
            '--@rules_rust//rust/settings:lto=fat',

            # https://github.com/bazelbuild/rules_swift
            # Enable whole module optimization.
            '--features=swift.opt_uses_wmo',

            # https://github.com/bazelbuild/rules_swift
            # Use -Osize instead of -O when building swift modules.
            '--features=swift.opt_uses_osize',

            # --num-threads 0 forces swiftc to generate one object file per module; it:
            # 1. resolves issues with the linker caused by the swift-objc mixing.
            # 2. makes the resulting binaries significantly smaller (up to 9% for this project).
            #'--swiftcopt=-num-threads', '--swiftcopt=1',
            #'--@build_bazel_rules_swift//swift:copt="-num-threads 0"',

            # Strip unsused code.
            '--features=dead_strip',
            '--objc_enable_binary_stripping',
        ]

    def set_lock(self, lock):
        self.lock = lock

    def add_remote_cache(self, host):
        self.remote_cache = host

    def add_cache_dir(self, path):
        self.cache_dir = path

    def add_additional_args(self, additional_args):
        self.additional_args = additional_args

    def set_build_number(self, build_number):
        self.build_number = build_number

    def set_custom_target(self, target_name):
        self.custom_target = target_name

    def set_continue_on_error(self, continue_on_error):
        self.continue_on_error = continue_on_error

    def set_show_actions(self, show_actions):
        self.show_actions = show_actions

    def set_enable_sandbox(self, enable_sandbox):
        self.enable_sandbox = enable_sandbox

    def set_split_swiftmodules(self, value):
        self.split_submodules = value

    def set_disable_provisioning_profiles(self):
        self.disable_provisioning_profiles = True

    def set_profile_swift(self, value):
        self.profile_swift = value

    def set_configuration(self, configuration):
        if configuration == 'debug_arm64':
            self.configuration_args = [
                # bazel debug build configuration
                '-c', 'dbg',

                # Build single-architecture binaries. It is almost 2 times faster is 32-bit support is not required.
                '--ios_multi_cpus=arm64',

                # Always build universal Watch binaries.
                '--watchos_cpus=arm64_32'
            ] + self.common_debug_args
        elif configuration == 'debug_sim_arm64':
            self.configuration_args = [
                # bazel debug build configuration
                '-c', 'dbg',

                # Build single-architecture binaries. It is almost 2 times faster is 32-bit support is not required.
                '--ios_multi_cpus=sim_arm64',

                # Always build universal Watch binaries.
                '--watchos_cpus=arm64_32'
            ] + self.common_debug_args
        elif configuration == 'release_sim_arm64':
            self.configuration_args = [
                # bazel optimized build configuration
                '-c', 'opt',

                # Build single-architecture binaries. It is almost 2 times faster is 32-bit support is not required.
                '--ios_multi_cpus=sim_arm64',

                # Always build universal Watch binaries.
                '--watchos_cpus=arm64_32'
            ] + self.common_debug_args
        elif configuration == 'release_arm64':
            self.configuration_args = [
                # bazel optimized build configuration
                '-c', 'opt',

                # Build single-architecture binaries. It is almost 2 times faster is 32-bit support is not required.
                '--ios_multi_cpus=arm64',

                # Always build universal Watch binaries.
                '--watchos_cpus=arm64_32',

                # Generate DSYM files when building.
                '--apple_generate_dsym',

                # Require DSYM files as build output.
                '--output_groups=+dsyms',
            ] + self.common_release_args
        else:
            raise Exception('Unknown configuration {}'.format(configuration))

    def set_watch_app(self, api_id, api_hash, signing_identity, provisioning_profile):
        self.embed_watch_app = True
        self.watch_api_id = api_id
        self.watch_api_hash = api_hash
        self.watch_signing_identity = signing_identity
        self.watch_provisioning_profile = provisioning_profile

    def get_startup_bazel_arguments(self):
        combined_arguments = []
        if self.bazel_user_root is not None:
            combined_arguments += ['--output_user_root={}'.format(self.bazel_user_root)]
        return combined_arguments

    def invoke_clean(self):
        combined_arguments = [
            self.build_environment.bazel_path
        ]
        combined_arguments += self.get_startup_bazel_arguments()
        combined_arguments += [
            'clean',
            '--expunge'
        ]

        print('TelegramBuild: running {}'.format(combined_arguments))
        call_executable(combined_arguments)

    def get_define_arguments(self):
        args = [
            '--define=buildNumber={}'.format(self.build_number),
        ]
        if self.embed_watch_app:
            args += ['--//Telegram:embedWatchApp']
            # watch_api_id/hash are guaranteed non-None here: set_watch_app is the only
            # setter of embed_watch_app, and build() raises if they are missing.
            args += [
                '--define=watchApiId={}'.format(self.watch_api_id),
                '--define=watchApiHash={}'.format(self.watch_api_hash),
                '--define=watchSigningIdentity={}'.format(self.watch_signing_identity or ''),
                '--define=watchProvisioningProfile={}'.format(self.watch_provisioning_profile or ''),
            ]
        return args

    def get_project_generation_arguments(self):
        combined_arguments = []
        combined_arguments += self.common_args
        combined_arguments += self.common_debug_args
        combined_arguments += self.get_define_arguments()

        if self.remote_cache is not None:
            combined_arguments += [
                '--remote_cache={}'.format(self.remote_cache),
                '--experimental_remote_downloader={}'.format(self.remote_cache)
            ]
        elif self.cache_dir is not None:
            combined_arguments += [
                '--disk_cache={path}'.format(path=self.cache_dir)
            ]

        if self.continue_on_error:
            combined_arguments += ['--keep_going']
        if self.show_actions:
            combined_arguments += ['--subcommands']

        return combined_arguments

    def get_additional_build_arguments(self):
        combined_arguments = []
        if self.split_submodules:
            combined_arguments += [
                # https://github.com/bazelbuild/rules_swift
                # If enabled and whole module optimisation is being used, the `*.swiftdoc`,
                # `*.swiftmodule` and `*-Swift.h` are generated with a separate action
                # rather than as part of the compilation.
                '--features=swift.split_derived_files_generation',
            ]

        return combined_arguments

    def invoke_build(self):
        combined_arguments = [
            self.build_environment.bazel_path
        ]
        combined_arguments += self.get_startup_bazel_arguments()
        combined_arguments += ['build']

        if self.lock:
            combined_arguments += ['--lockfile_mode=error']

        if self.custom_target is not None:
            combined_arguments += [self.custom_target]
        else:
            combined_arguments += ['Telegram/Telegram']

        if self.continue_on_error:
            combined_arguments += ['--keep_going']
        if self.show_actions:
            combined_arguments += ['--subcommands']

        if self.enable_sandbox:
            combined_arguments += ['--spawn_strategy=sandboxed']

        if self.disable_provisioning_profiles:
            combined_arguments += ['--//Telegram:disableProvisioningProfiles']

        combined_arguments += self.common_args
        combined_arguments += self.common_build_args
        combined_arguments += self.get_define_arguments()
        combined_arguments += self.get_additional_build_arguments()

        if self.remote_cache is not None:
            combined_arguments += [
                '--remote_cache={}'.format(self.remote_cache),
                '--experimental_remote_downloader={}'.format(self.remote_cache)
            ]
        elif self.cache_dir is not None:
            combined_arguments += [
                '--disk_cache={path}'.format(path=self.cache_dir)
            ]

        combined_arguments += self.configuration_args
        if self.profile_swift:
            combined_arguments += ['--config=swift_profile']

        print('TelegramBuild: running')
        print(subprocess.list2cmdline(combined_arguments))
        call_executable(combined_arguments)

    def invoke_test(self, test_target='Tests/AllTests'):
        combined_arguments = [
            self.build_environment.bazel_path
        ]
        combined_arguments += self.get_startup_bazel_arguments()
        combined_arguments += ['test']

        combined_arguments += ['--cache_test_results=no']
        combined_arguments += ['--test_output=errors']

        combined_arguments += [test_target]

        combined_arguments += self.common_args
        combined_arguments += self.common_build_args
        combined_arguments += self.get_define_arguments()
        combined_arguments += self.get_additional_build_arguments()

        if self.remote_cache is not None:
            combined_arguments += [
                '--remote_cache={}'.format(self.remote_cache),
                '--experimental_remote_downloader={}'.format(self.remote_cache)
            ]
        elif self.cache_dir is not None:
            combined_arguments += [
                '--disk_cache={path}'.format(path=self.cache_dir)
            ]

        combined_arguments += self.configuration_args

        print('TelegramBuild: running')
        print(subprocess.list2cmdline(combined_arguments))
        call_executable(combined_arguments)

    def invoke_query(self, query_args):
        combined_arguments = [
            self.build_environment.bazel_path
        ]
        combined_arguments += self.get_startup_bazel_arguments()
        combined_arguments += ['aquery']

        combined_arguments += [
            '-c', 'dbg',
            '--ios_multi_cpus=sim_arm64',
        ]

        combined_arguments += self.get_define_arguments()

        if self.remote_cache is not None:
            combined_arguments += [
                '--remote_cache={}'.format(self.remote_cache),
                '--experimental_remote_downloader={}'.format(self.remote_cache)
            ]
        elif self.cache_dir is not None:
            combined_arguments += [
                '--disk_cache={path}'.format(path=self.cache_dir)
            ]

        # Add user-provided query arguments
        combined_arguments += query_args

        print('TelegramBuild: running')
        print(subprocess.list2cmdline(combined_arguments))
        call_executable(combined_arguments)

    def invoke_spm_build(self):
        combined_arguments = [
            self.build_environment.bazel_path
        ]
        combined_arguments += self.get_startup_bazel_arguments()
        combined_arguments += ['build']

        # Build the generate_spm target directly to get the dependency tree JSON
        combined_arguments += ['//Telegram:spm_build_root']

        if self.continue_on_error:
            combined_arguments += ['--keep_going']
        if self.show_actions:
            combined_arguments += ['--subcommands']

        if self.enable_sandbox:
            combined_arguments += ['--spawn_strategy=sandboxed']

        if self.disable_provisioning_profiles:
            combined_arguments += ['--//Telegram:disableProvisioningProfiles']

        combined_arguments += self.common_args
        combined_arguments += self.common_build_args
        combined_arguments += self.get_define_arguments()
        combined_arguments += self.get_additional_build_arguments()

        if self.remote_cache is not None:
            combined_arguments += [
                '--remote_cache={}'.format(self.remote_cache),
                '--experimental_remote_downloader={}'.format(self.remote_cache)
            ]
        elif self.cache_dir is not None:
            combined_arguments += [
                '--disk_cache={path}'.format(path=self.cache_dir)
            ]

        combined_arguments += self.configuration_args

        print(subprocess.list2cmdline(combined_arguments))
        call_executable(combined_arguments)


def clean(bazel, arguments):
    bazel_command_line = BazelCommandLine(
        bazel=bazel,
        override_bazel_version=arguments.overrideBazelVersion,
        override_xcode_version=arguments.overrideXcodeVersion,
        bazel_user_root=arguments.bazelUserRoot
    )

    bazel_command_line.invoke_clean()


def resolve_codesigning(arguments, base_path, build_configuration, provisioning_profiles_path, additional_codesigning_output_path) -> ResolvedCodesigningData:
    profile_source = None
    if arguments.gitCodesigningRepository is not None:
        password = os.getenv('TELEGRAM_CODESIGNING_GIT_PASSWORD')
        if password is None:
            print('TELEGRAM_CODESIGNING_GIT_PASSWORD environment variable is not set')
            sys.exit(1)

        if arguments.gitCodesigningType is None:
            print('--gitCodesigningType is required if --gitCodesigningRepository is set')
            sys.exit(1)

        private_key = os.getenv('TELEGRAM_CODESIGNING_PRIVATE_KEY')

        profile_source = GitCodesigningSource(
            repo_url=arguments.gitCodesigningRepository,
            private_key=private_key,
            team_id=build_configuration.team_id,
            bundle_id=build_configuration.bundle_id,
            codesigning_type=arguments.gitCodesigningType,
            password=password,
            always_fetch=not arguments.gitCodesigningUseCurrent
        )
    elif arguments.codesigningInformationPath is not None:
        profile_source = DirectoryCodesigningSource(
            directory_path=arguments.codesigningInformationPath,
            team_id=build_configuration.team_id,
            bundle_id=build_configuration.bundle_id
        )
    elif arguments.xcodeManagedCodesigning is not None and arguments.xcodeManagedCodesigning == True:
        profile_source = XcodeManagedCodesigningSource()
    else:
        raise Exception('Neither gitCodesigningRepository nor codesigningInformationPath are set')

    workdir_path = '{}/build-input/configuration-repository-workdir'.format(base_path)
    os.makedirs(workdir_path, exist_ok=True)
    profile_source.load_data(working_dir=workdir_path)

    if provisioning_profiles_path is not None:
        profile_source.copy_profiles_to_destination(destination_path=provisioning_profiles_path)

    if additional_codesigning_output_path is not None:
        profile_source.copy_profiles_to_destination(destination_path=additional_codesigning_output_path + '/profiles')
        profile_source.copy_certificates_to_destination(destination_path=additional_codesigning_output_path + '/certs')

    return ResolvedCodesigningData(
        aps_environment=profile_source.resolve_aps_environment(),
        use_xcode_managed_codesigning=profile_source.use_xcode_managed_codesigning()
    )


def resolve_configuration(base_path, bazel_command_line: BazelCommandLine, arguments, additional_codesigning_output_path):
    configuration_repository_path = '{}/build-input/configuration-repository'.format(base_path)
    os.makedirs(configuration_repository_path, exist_ok=True)

    build_configuration = build_configuration_from_json(path=arguments.configurationPath)

    with open(configuration_repository_path + '/WORKSPACE', 'w+') as file:
        pass

    with open(configuration_repository_path + '/MODULE.bazel', 'w+') as file:
        file.write('module(\n    name = "build_configuration",\n)\n')

    with open(configuration_repository_path + '/BUILD', 'w+') as file:
        pass

    provisioning_path = '{}/provisioning'.format(configuration_repository_path)
    if os.path.exists(provisioning_path):
        shutil.rmtree(provisioning_path)
    os.makedirs(provisioning_path, exist_ok=True)

    codesigning_data = resolve_codesigning(
        arguments=arguments,
        base_path=base_path,
        build_configuration=build_configuration,
        provisioning_profiles_path=provisioning_path,
        additional_codesigning_output_path=additional_codesigning_output_path
    )
    if codesigning_data.aps_environment is None:
        print('Could not find a valid aps-environment entitlement in the provided provisioning profiles')
        sys.exit(1)

    if bazel_command_line is not None:
        build_configuration.write_to_variables_file(bazel_path=bazel_command_line.bazel, use_xcode_managed_codesigning=codesigning_data.use_xcode_managed_codesigning, aps_environment=codesigning_data.aps_environment, path=configuration_repository_path + '/variables.bzl')

    provisioning_profile_files = []
    for file_name in os.listdir(provisioning_path):
        if file_name.endswith('.mobileprovision'):
            provisioning_profile_files.append(file_name)

    with open(provisioning_path + '/BUILD', 'w+') as file:
        file.write('exports_files([\n')
        for file_name in provisioning_profile_files:
            file.write('    "{}",\n'.format(file_name))
        file.write('])\n')


def generate_project(bazel, arguments):
    bazel_command_line = BazelCommandLine(
        bazel=bazel,
        override_bazel_version=arguments.overrideBazelVersion,
        override_xcode_version=arguments.overrideXcodeVersion,
        bazel_user_root=arguments.bazelUserRoot
    )

    if arguments.cacheDir is not None:
        bazel_command_line.add_cache_dir(arguments.cacheDir)
    elif arguments.cacheHost is not None:
        bazel_command_line.add_remote_cache(arguments.cacheHost)

    bazel_command_line.set_continue_on_error(arguments.continueOnError)

    resolve_configuration(
        base_path=os.getcwd(),
        bazel_command_line=bazel_command_line,
        arguments=arguments,
        additional_codesigning_output_path=None
    )

    bazel_command_line.set_build_number(arguments.buildNumber)

    disable_extensions = False
    disable_provisioning_profiles = False
    project_include_release = False
    generate_dsym = False
    target_name = "Telegram"

    if arguments.disableExtensions is not None:
        disable_extensions = arguments.disableExtensions
    if arguments.disableProvisioningProfiles is not None:
        disable_provisioning_profiles = arguments.disableProvisioningProfiles
    if arguments.projectIncludeRelease is not None:
        project_include_release = arguments.projectIncludeRelease
    if arguments.xcodeManagedCodesigning is not None and arguments.xcodeManagedCodesigning == True:
        disable_extensions = True
    if arguments.generateDsym is not None:
        generate_dsym = arguments.generateDsym
    if arguments.target is not None:
        target_name = arguments.target
    
    call_executable(['killall', 'Xcode'], check_result=False)

    xcodeproj_path = generate(
        build_environment=bazel_command_line.build_environment,
        disable_extensions=disable_extensions,
        disable_provisioning_profiles=disable_provisioning_profiles,
        include_release=project_include_release,
        generate_dsym=generate_dsym,
        bazel_app_arguments=bazel_command_line.get_project_generation_arguments(),
        target_name=target_name
    )

    call_executable(['open', xcodeproj_path])


def resolve_watch_provisioning_profile(arguments, base_path):
    """Resolve the watchkitapp provisioning profile for an --embedWatchApp build.

    Returns the absolute path of the profile to sign the embedded watch app with, or None
    to build the watch app UNSIGNED. None is only returned (with a warning) for
    non-distribution codesigning — a distribution build (appstore/adhoc/enterprise) raises
    instead, because the host ios_application does NOT re-sign the embedded watch app, so an
    unsigned Watch/ payload ships as-is and is silently rejected at install time. Failing
    here turns that silent "won't install" into a build error that names the missing profile.
    """
    is_distribution_codesigning = arguments.gitCodesigningType in ('appstore', 'adhoc', 'enterprise')

    explicit_profile = arguments.watchProvisioningProfile
    if explicit_profile is not None:
        if not os.path.exists(explicit_profile):
            raise Exception('--watchProvisioningProfile was set to a path that does not exist: {}'.format(explicit_profile))
        return explicit_profile

    # Default to the watchkitapp profile that resolve_configuration() just extracted from the
    # codesigning material (renamed via the bundle-id mapping in BuildConfiguration.py). This
    # matches the active codesigning type (e.g. appstore) and the host app's identity, so the
    # embedded watch app is signed correctly without an explicit --watchProvisioningProfile.
    # The worker derives the signing identity (cert) from this profile when
    # --watchSigningIdentity is omitted.
    resolved_watch_profile = os.path.join(base_path, 'build-input/configuration-repository/provisioning/WatchApp.mobileprovision')
    if os.path.exists(resolved_watch_profile):
        return resolved_watch_profile

    if is_distribution_codesigning:
        raise Exception(
            '--embedWatchApp is set for a distribution build (--gitCodesigningType={ct}), but no watchkitapp '
            'provisioning profile resolved (looked for {p}).\n'
            'The {ct} codesigning material does not contain a `.watchkitapp` profile, so the embedded watch app '
            'would be UNSIGNED — the host app is not re-signed over it, so it ships unsigned and is silently '
            'rejected when installing on a watch.\n'
            'Fix: fetch the latest codesigning material so the watchkitapp profile is present — drop '
            '--gitCodesigningUseCurrent (it skips the fetch), or run '
            '`git -C build-input/configuration-repository-workdir/encrypted pull` — or create/register the {ct} '
            'watchkitapp provisioning profile, or pass an explicit --watchProvisioningProfile.'.format(
                ct=arguments.gitCodesigningType, p=resolved_watch_profile
            )
        )

    print('TelegramBuild: warning: --embedWatchApp is set but no watch provisioning profile was found (pass --watchProvisioningProfile, or use codesigning material that includes the watchkitapp profile; looked for {}). The embedded watch app will be UNSIGNED and rejected by the App Store.'.format(resolved_watch_profile))
    return None


def build(bazel, arguments):
    bazel_command_line = BazelCommandLine(
        bazel=bazel,
        override_bazel_version=arguments.overrideBazelVersion,
        override_xcode_version=arguments.overrideXcodeVersion,
        bazel_user_root=arguments.bazelUserRoot
    )

    if arguments.lock:
        bazel_command_line.set_lock(True)

    if arguments.cacheDir is not None:
        bazel_command_line.add_cache_dir(arguments.cacheDir)
    elif arguments.cacheHost is not None:
        bazel_command_line.add_remote_cache(arguments.cacheHost)

    resolve_configuration(
        base_path=os.getcwd(),
        bazel_command_line=bazel_command_line,
        arguments=arguments,
        additional_codesigning_output_path=None
    )

    bazel_command_line.set_configuration(arguments.configuration)
    if arguments.embedWatchApp:
        if arguments.configuration in ('debug_arm64', 'release_arm64'):
            if arguments.watchApiId is None or arguments.watchApiHash is None:
                raise Exception('--embedWatchApp requires --watchApiId and --watchApiHash (the embedded watch app build needs API credentials).')
            watch_provisioning_profile = resolve_watch_provisioning_profile(arguments=arguments, base_path=os.getcwd())
            bazel_command_line.set_watch_app(
                arguments.watchApiId,
                arguments.watchApiHash,
                arguments.watchSigningIdentity,
                watch_provisioning_profile
            )
        else:
            print('TelegramBuild: warning: --embedWatchApp requires a device configuration (debug_arm64 or release_arm64); ignored for simulator builds.')
    bazel_command_line.set_build_number(arguments.buildNumber)
    bazel_command_line.set_custom_target(arguments.target)
    bazel_command_line.set_continue_on_error(arguments.continueOnError)
    bazel_command_line.set_show_actions(arguments.showActions)
    bazel_command_line.set_enable_sandbox(arguments.sandbox)
    bazel_command_line.set_profile_swift(arguments.profileSwift)

    bazel_command_line.set_split_swiftmodules(arguments.enableParallelSwiftmoduleGeneration)

    bazel_command_line.invoke_build()

    if arguments.outputBuildArtifactsPath is not None:
        artifacts_path = os.path.abspath(arguments.outputBuildArtifactsPath)
        if os.path.exists(artifacts_path + '/Telegram.ipa'):
            os.remove(artifacts_path + '/Telegram.ipa')
        if os.path.exists(artifacts_path + '/DSYMs'):
            shutil.rmtree(artifacts_path + '/DSYMs')
        os.makedirs(artifacts_path, exist_ok=True)
        os.makedirs(artifacts_path + '/DSYMs', exist_ok=True)

        built_ipa_path_prefix = 'bazel-bin/Telegram'
        ipa_paths = glob.glob('{}/Telegram.ipa'.format(built_ipa_path_prefix))
        if len(ipa_paths) == 0:
            print(f'Could not find the IPA at {built_ipa_path_prefix}/Telegram.ipa')
            sys.exit(1)
        elif len(ipa_paths) > 1:
            print('Multiple matching IPA files found: {}'.format(ipa_paths))
            sys.exit(1)
        shutil.copyfile(ipa_paths[0], artifacts_path + '/Telegram.ipa')

        dsym_paths = glob.glob('bazel-bin/Telegram/*.dSYM')
        for dsym_path in dsym_paths:
            file_name = os.path.basename(dsym_path)
            shutil.copytree(dsym_path, artifacts_path + '/DSYMs/{}'.format(file_name))
        previous_directory = os.getcwd()
        os.chdir(artifacts_path)
        run_executable_with_output('zip', arguments=[
            '-r',
            'Telegram.DSYMs.zip',
            './DSYMs'
        ], check_result=True)
        os.chdir(previous_directory)
        shutil.rmtree(artifacts_path + '/DSYMs')


def test(bazel, arguments):
    bazel_command_line = BazelCommandLine(
        bazel=bazel,
        override_bazel_version=arguments.overrideBazelVersion,
        override_xcode_version=arguments.overrideXcodeVersion,
        bazel_user_root=arguments.bazelUserRoot
    )

    if arguments.cacheDir is not None:
        bazel_command_line.add_cache_dir(arguments.cacheDir)
    elif arguments.cacheHost is not None:
        bazel_command_line.add_remote_cache(arguments.cacheHost)

    resolve_configuration(
        base_path=os.getcwd(),
        bazel_command_line=bazel_command_line,
        arguments=arguments,
        additional_codesigning_output_path=None
    )

    bazel_command_line.set_configuration('debug_sim_arm64')
    bazel_command_line.set_build_number('10000')

    bazel_command_line.invoke_test(test_target=arguments.target)


def query(bazel, arguments):
    bazel_command_line = BazelCommandLine(
        bazel=bazel,
        override_bazel_version=arguments.overrideBazelVersion,
        override_xcode_version=arguments.overrideXcodeVersion,
        bazel_user_root=arguments.bazelUserRoot
    )

    if arguments.cacheDir is not None:
        bazel_command_line.add_cache_dir(arguments.cacheDir)
    elif arguments.cacheHost is not None:
        bazel_command_line.add_remote_cache(arguments.cacheHost)

    # Resolve configuration if needed
    if arguments.configurationPath is not None:
        resolve_configuration(
            base_path=os.getcwd(),
            bazel_command_line=bazel_command_line,
            arguments=arguments,
            additional_codesigning_output_path=None
        )

    # Parse the query arguments
    query_args = []
    if arguments.queryArgs:
        query_args = shlex.split(arguments.queryArgs)

    bazel_command_line.invoke_query(query_args)


def build_spm(bazel, arguments):
    bazel_command_line = BazelCommandLine(
        bazel=bazel,
        override_bazel_version=arguments.overrideBazelVersion,
        override_xcode_version=arguments.overrideXcodeVersion,
        bazel_user_root=arguments.bazelUserRoot
    )

    if arguments.cacheDir is not None:
        bazel_command_line.add_cache_dir(arguments.cacheDir)
    elif arguments.cacheHost is not None:
        bazel_command_line.add_remote_cache(arguments.cacheHost)

    resolve_configuration(
        base_path=os.getcwd(),
        bazel_command_line=bazel_command_line,
        arguments=arguments,
        additional_codesigning_output_path=None
    )

    bazel_command_line.set_configuration(arguments.configuration)
    bazel_command_line.set_build_number(arguments.buildNumber)
    bazel_command_line.set_continue_on_error(False)
    bazel_command_line.set_show_actions(False)
    bazel_command_line.set_enable_sandbox(False)
    bazel_command_line.set_split_swiftmodules(False)

    bazel_command_line.invoke_spm_build()

def add_codesigning_common_arguments(current_parser: argparse.ArgumentParser):
    configuration_group = current_parser.add_mutually_exclusive_group(required=True)
    configuration_group.add_argument(
        '--configurationPath',
        help='''
            Path to a json containing build configuration.
            See build-system/appstore-configuration.json for an example.
            ''',
        metavar='path'
    )

    codesigning_group = current_parser.add_mutually_exclusive_group(required=True)
    codesigning_group.add_argument(
        '--gitCodesigningRepository',
        help='''
            If specified, certificates and provisioning profiles will be loaded from git.
            TELEGRAM_CODESIGNING_GIT_PASSWORD environment variable must be set.
            ''',
        metavar='path'
    )
    codesigning_group.add_argument(
        '--codesigningInformationPath',
        help='''
            Use signing certificates and provisioning profiles from a local directory.
            ''',
        metavar='command'
    )
    codesigning_group.add_argument(
        '--xcodeManagedCodesigning',
        action='store_true',
        help='''
            Let Xcode manage your certificates and provisioning profiles.
            ''',
    )

    current_parser.add_argument(
        '--gitCodesigningType',
        choices=[
            'development',
            'adhoc',
            'appstore',
            'enterprise'
        ],
        required=False,
        help='''
            The name of the folder to use inside "profiles" folder in the git repository.
            Required if gitCodesigningRepository is specified.
            ''',
        metavar='type'
    )

    current_parser.add_argument(
        '--gitCodesigningUseCurrent',
        action='store_true',
        required=False,
        default=False,
        help='''
            Always refresh codesigning repository.
            '''
    )


def add_project_and_build_common_arguments(current_parser: argparse.ArgumentParser):
    add_codesigning_common_arguments(current_parser=current_parser)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='Make')

    parser.add_argument(
        '--verbose',
        action='store_true',
        default=False,
        help='Print debug info'
    )

    parser.add_argument(
        '--bazel',
        required=False,
        help='Use custom bazel binary',
        metavar='path'
    )

    parser.add_argument(
        '--bazelUserRoot',
        required=False,
        help='Use custom bazel user root (useful when reproducing a build)',
        metavar='path'
    )

    parser.add_argument(
        '--overrideBazelVersion',
        action='store_true',
        help='Override bazel version with the actual version reported by the bazel binary'
    )

    parser.add_argument(
        '--overrideXcodeVersion',
        action='store_true',
        help='Override xcode version with the actual version reported by \'xcode-select -p\''
    )

    parser.add_argument(
        '--bazelArguments',
        required=False,
        help='Add additional arguments to all bazel invocations.',
        metavar='arguments'
    )

    cacheTypeGroup = parser.add_mutually_exclusive_group()
    cacheTypeGroup.add_argument(
        '--cacheHost',
        required=False,
        help='Use remote build artifact cache to speed up rebuilds (See https://github.com/buchgr/bazel-remote).',
        metavar='grpc://host:9092'
    )
    cacheTypeGroup.add_argument(
        '--cacheDir',
        required=False,
        help='Cache build artifacts in a local directory to speed up rebuilds.',
        metavar='path'
    )

    subparsers = parser.add_subparsers(dest='commandName', help='Commands')

    cleanParser = subparsers.add_parser(
        'clean', help='''
            Clean local bazel cache. Does not affect files cached remotely (via --cacheHost=...) or 
            locally in an external directory ('--cacheDir=...')
            '''
    )

    testParser = subparsers.add_parser(
        'test', help='''
            Run all tests.
            '''
    )
    add_project_and_build_common_arguments(testParser)
    testParser.add_argument(
        '--target',
        type=str,
        default='Tests/AllTests',
        help='Bazel test target to run (default: Tests/AllTests, the full suite).'
    )

    generateProjectParser = subparsers.add_parser('generateProject', help='Generate Xcode project')
    generateProjectParser.add_argument(
        '--buildNumber',
        required=False,
        type=int,
        default=10000,
        help='Build number.',
        metavar='number'
    )
    add_project_and_build_common_arguments(generateProjectParser)
    generateProjectParser.add_argument(
        '--disableExtensions',
        action='store_true',
        default=False,
        help='''
            The generated project will not include app extensions.
            This allows Xcode to properly index the source code.
            '''
    )

    generateProjectParser.add_argument(
        '--continueOnError',
        action='store_true',
        default=False,
        help='Continue build process after an error.',
    )

    generateProjectParser.add_argument(
        '--disableProvisioningProfiles',
        action='store_true',
        default=False,
        help='''
            This allows to build the project for simulator without having any codesigning identities installed.
            Building for an actual device will fail.
            '''
    )

    generateProjectParser.add_argument(
        '--projectIncludeRelease',
        action='store_true',
        default=False,
        help='''
            Generate the Xcode project with Debug and Release configurations.
            '''
    )

    generateProjectParser.add_argument(
        '--generateDsym',
        action='store_true',
        default=False,
        help='''
            This improves profiling experinence by generating DSYM files. Keep disabled for better build performance.
            '''
    )

    generateProjectParser.add_argument(
        '--target',
        type=str,
        help='A custom bazel target name to build.',
        metavar='target_name'
    )

    buildParser = subparsers.add_parser('build', help='Build the app')
    buildParser.add_argument(
        '--buildNumber',
        required=True,
        type=int,
        help='Build number.',
        metavar='number'
    )
    add_project_and_build_common_arguments(buildParser)
    buildParser.add_argument(
        '--configuration',
        choices=[
            'debug_arm64',
            'debug_sim_arm64',
            'release_sim_arm64',
            'release_arm64',
        ],
        required=True,
        help='Build configuration'
    )
    buildParser.add_argument(
        '--enableParallelSwiftmoduleGeneration',
        action='store_true',
        default=False,
        help='Generate .swiftmodule files in parallel to building modules, can speed up compilation on multi-core '
             'systems. '
    )
    buildParser.add_argument(
        '--profileSwift',
        action='store_true',
        default=False,
        help='Enable single-core Swift compile profiling flags.'
    )
    buildParser.add_argument(
        '--target',
        type=str,
        help='A custom bazel target name to build.',
        metavar='target_name'
    )
    buildParser.add_argument(
        '--continueOnError',
        action='store_true',
        default=False,
        help='Continue build process after an error.',
    )
    buildParser.add_argument(
        '--showActions',
        action='store_true',
        default=False,
        help='Show bazel actions.',
    )
    buildParser.add_argument(
        '--sandbox',
        action='store_true',
        default=False,
        help='Enable sandbox.',
    )
    buildParser.add_argument(
        '--outputBuildArtifactsPath',
        required=False,
        help='Store IPA and DSYM at the specified path after a successful build.',
        metavar='arguments'
    )
    buildParser.add_argument(
        '--lock',
        action='store_true',
        default=False,
        help='Respect MODULE.bazel.lock.'
    )
    buildParser.add_argument(
        '--embedWatchApp',
        action='store_true',
        default=False,
        help='Embed the tgwatch watch app (from the in-repo Telegram/WatchApp snapshot) under Watch/ in a device build.'
    )
    buildParser.add_argument(
        '--watchApiId',
        required=False,
        type=str,
        help='TG_API_ID for the watch build.',
        metavar='api_id'
    )
    buildParser.add_argument(
        '--watchApiHash',
        required=False,
        type=str,
        help='TG_API_HASH for the watch build.',
        metavar='api_hash'
    )
    buildParser.add_argument(
        '--watchSigningIdentity',
        required=False,
        type=str,
        help='Codesigning identity (SHA1 hash) for the watch app.',
        metavar='identity'
    )
    buildParser.add_argument(
        '--watchProvisioningProfile',
        required=False,
        type=str,
        help='Absolute path to the watchkitapp .mobileprovision file.',
        metavar='path'
    )

    remote_build_parser = subparsers.add_parser('remote-build', help='Build the app using a remote environment.')
    add_codesigning_common_arguments(remote_build_parser)
    remote_build_parser.add_argument(
        '--darwinContainersHost',
        required=True,
        type=str,
        help='DarwinContainers host address.'
    )
    remote_build_parser.add_argument(
        '--darwinContainers',
        required=True,
        type=str,
        help='DarwinContainers script path.'
    )
    remote_build_parser.add_argument(
        '--configuration',
        choices=[
            'release_arm64',
        ],
        required=True,
        help='Build configuration'
    )
    remote_build_parser.add_argument(
        '--cacheHost',
        required=False,
        type=str,
        help='Bazel remote cache host address.'
    )
    remote_build_parser.add_argument(
        '--embedWatchApp',
        action='store_true',
        default=False,
        help='Embed the tgwatch watch app (from the in-repo Telegram/WatchApp snapshot) under Watch/ in the remote device build.'
    )
    remote_build_parser.add_argument(
        '--watchApiId',
        required=False,
        type=str,
        help='TG_API_ID for the watch build.',
        metavar='api_id'
    )
    remote_build_parser.add_argument(
        '--watchApiHash',
        required=False,
        type=str,
        help='TG_API_HASH for the watch build.',
        metavar='api_hash'
    )
    remote_build_parser.add_argument(
        '--watchSigningIdentity',
        required=False,
        type=str,
        help='Codesigning identity (SHA1 hash) for the watch app. The matching certificate must be present in the uploaded codesigning material.',
        metavar='identity'
    )
    remote_build_parser.add_argument(
        '--watchProvisioningProfile',
        required=False,
        type=str,
        help='Local absolute path to the watchkitapp .mobileprovision file; uploaded to the remote build environment.',
        metavar='path'
    )

    vm_build_parser = subparsers.add_parser('vm-build', help='Build the app using a VM.')
    add_codesigning_common_arguments(vm_build_parser)
    vm_build_parser.add_argument(
        '--configuration',
        choices=[
            'release_arm64',
        ],
        required=True,
        help='Build configuration'
    )
    vm_build_parser.add_argument(
        '--cacheHost',
        required=False,
        type=str,
        help='Bazel remote cache host address.'
    )
    vm_build_parser.add_argument(
        '--vmImage',
        required=False,
        type=str,
        help='Name of the Tart image to clone. Defaults to macos-<macos_version>-xcode-<xcode_version> as declared in versions.json.',
        metavar='name'
    )
    vm_build_parser.add_argument(
        '--persistentVM',
        action='store_true',
        default=False,
        help='Reuse the VM named by --vmImage instead of cloning a throwaway copy of it. The VM is booted in place and kept afterwards, so its guest-side bazel cache and source tree survive between builds.'
    )
    vm_build_parser.add_argument(
        '--vmCpu',
        required=False,
        type=int,
        help='Number of CPUs to give the ephemeral VM clone. Defaults to the host CPU count minus one. Not valid with --persistentVM, which uses the VM as it is configured.',
        metavar='n'
    )
    vm_build_parser.add_argument(
        '--vmMemory',
        required=False,
        type=int,
        help='Memory in megabytes to give the ephemeral VM clone. Defaults to half of host memory, capped at 32 GB. Not valid with --persistentVM, which uses the VM as it is configured.',
        metavar='megabytes'
    )

    generate_profiles_build_parser = subparsers.add_parser('generate-verification-profiles', help='Generate provisioning profiles that can be used to build a veritication IPA.')
    add_codesigning_common_arguments(generate_profiles_build_parser)
    generate_profiles_build_parser.add_argument(
        '--destination',
        required=True,
        type=str,
        help='Path to the destination directory.'
    )
    generate_profiles_build_parser.add_argument(
        '--certsPath',
        required=False,
        type=str,
        default='build-system/fake-codesigning/certs',
        help='Path to the directory containing SelfSigned.p12 certificate.'
    )

    remote_upload_testflight_parser = subparsers.add_parser('remote-deploy-testflight', help='Build the app using a remote environment.')
    remote_upload_testflight_parser.add_argument(
        '--darwinContainersHost',
        required=True,
        type=str,
        help='DarwinContainers host address.'
    )
    remote_upload_testflight_parser.add_argument(
        '--darwinContainers',
        required=True,
        type=str,
        help='DarwinContainers script path.'
    )
    remote_upload_testflight_parser.add_argument(
        '--ipa',
        required=True,
        type=str,
        help='Path to IPA file.'
    )
    remote_upload_testflight_parser.add_argument(
        '--dsyms',
        required=True,
        type=str,
        help='Path to DSYMs.zip file.'
    )

    remote_ipadiff_parser = subparsers.add_parser('remote-ipa-diff', help='Execute ipa-diff using a remote environment.')
    remote_ipadiff_parser.add_argument(
        '--darwinContainersHost',
        required=True,
        type=str,
        help='DarwinContainers host address.'
    )
    remote_ipadiff_parser.add_argument(
        '--darwinContainers',
        required=True,
        type=str,
        help='DarwinContainers script path.'
    )
    remote_ipadiff_parser.add_argument(
        '--ipa1',
        required=True,
        type=str,
        help='Path to IPA 1 file.'
    )
    remote_ipadiff_parser.add_argument(
        '--ipa2',
        required=True,
        type=str,
        help='Path to IPA 2 file.'
    )

    query_parser = subparsers.add_parser('query', help='Run arbitrary bazel queries')
    # Configuration is optional for queries
    query_parser.add_argument(
        '--configurationPath',
        required=False,
        help='''
            Path to a json containing build configuration.
            See build-system/appstore-configuration.json for an example.
            ''',
        metavar='path'
    )
    # Codesigning arguments are optional for queries
    query_parser.add_argument(
        '--gitCodesigningRepository',
        required=False,
        help='''
            If specified, certificates and provisioning profiles will be loaded from git.
            TELEGRAM_CODESIGNING_GIT_PASSWORD environment variable must be set.
            ''',
        metavar='path'
    )
    query_parser.add_argument(
        '--codesigningInformationPath',
        required=False,
        help='''
            Use signing certificates and provisioning profiles from a local directory.
            ''',
        metavar='command'
    )
    query_parser.add_argument(
        '--xcodeManagedCodesigning',
        action='store_true',
        help='''
            Let Xcode manage your certificates and provisioning profiles.
            ''',
    )
    query_parser.add_argument(
        '--gitCodesigningType',
        choices=[
            'development',
            'adhoc',
            'appstore',
            'enterprise'
        ],
        required=False,
        help='''
            The name of the folder to use inside "profiles" folder in the git repository.
            Required if gitCodesigningRepository is specified.
            ''',
        metavar='type'
    )
    query_parser.add_argument(
        '--gitCodesigningUseCurrent',
        action='store_true',
        required=False,
        default=False,
        help='''
            Always refresh codesigning repository.
            '''
    )
    query_parser.add_argument(
        '--queryArgs',
        required=True,
        help='The query command and arguments to pass to bazel.',
        metavar='query_string'
    )

    spm_parser = subparsers.add_parser('spm', help='Generate SPM package (outputs bazel-bin/Telegram/spm_build_root_modules.json)')
    spm_parser.add_argument(
        '--buildNumber',
        required=False,
        type=int,
        default=10000,
        help='Build number.',
        metavar='number'
    )
    spm_parser.add_argument(
        '--configuration',
        choices=[
            'debug_arm64',
            'debug_sim_arm64',
            'release_sim_arm64',
            'release_arm64',
        ],
        required=True,
        help='Build configuration'
    )
    add_codesigning_common_arguments(spm_parser)

    if len(sys.argv) < 2:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    if args.verbose:
        print(args)

    if args.commandName is None:
        sys.exit(0)

    bazel_path = None
    if args.bazel is None:
        bazel_path = locate_bazel(base_path=os.getcwd(), cache_host_or_path=args.cacheHost, cache_dir=args.cacheDir)
    else:
        bazel_path = args.bazel

    try:
        if args.commandName == 'clean':
            clean(bazel=bazel_path, arguments=args)
        elif args.commandName == 'generateProject':
            generate_project(bazel=bazel_path, arguments=args)
        elif args.commandName == 'build':
            build(bazel=bazel_path, arguments=args)
        elif args.commandName == 'remote-build':
            base_path = os.getcwd()
            remote_input_path = '{}/build-input/remote-input'.format(base_path)
            if os.path.exists(remote_input_path):
                shutil.rmtree(remote_input_path)
            os.makedirs(remote_input_path)
            os.makedirs(remote_input_path + '/certs')
            os.makedirs(remote_input_path + '/profiles')

            versions = BuildEnvironmentVersions(base_path=os.getcwd())

            resolve_configuration(
                base_path=os.getcwd(),
                bazel_command_line=None,
                arguments=args,
                additional_codesigning_output_path=remote_input_path
            )
            
            shutil.copyfile(args.configurationPath, remote_input_path + '/configuration.json')

            watch_provisioning_profile_remote_path = None
            if args.embedWatchApp:
                if args.watchApiId is None or args.watchApiHash is None:
                    raise Exception('--embedWatchApp requires --watchApiId and --watchApiHash (the embedded watch app build needs API credentials).')
                if args.watchProvisioningProfile is not None:
                    shutil.copyfile(args.watchProvisioningProfile, remote_input_path + '/watch_provisioning_profile.mobileprovision')
                    # remote_input_path is uploaded to the guest as $HOME/telegram-build-input.
                    watch_provisioning_profile_remote_path = '$HOME/telegram-build-input/watch_provisioning_profile.mobileprovision'

            RemoteBuild.remote_build_darwin_containers(
                darwin_containers_path=args.darwinContainers,
                darwin_containers_host=args.darwinContainersHost,
                macos_version=versions.macos_version,
                bazel_cache_host=args.cacheHost,
                configuration=args.configuration,
                build_input_data_path=remote_input_path,
                embed_watch_app=args.embedWatchApp,
                watch_api_id=args.watchApiId,
                watch_api_hash=args.watchApiHash,
                watch_signing_identity=args.watchSigningIdentity,
                watch_provisioning_profile_remote_path=watch_provisioning_profile_remote_path
            )
        elif args.commandName == 'vm-build':
            # Checked before the codesigning repository work below, so a bad combination
            # fails at once instead of after a git checkout.
            if args.persistentVM and (args.vmCpu is not None or args.vmMemory is not None):
                raise Exception('--vmCpu and --vmMemory are not valid with --persistentVM: a persistent VM is used as it is configured.')

            base_path = os.getcwd()
            versions = BuildEnvironmentVersions(base_path=base_path)

            # The lock is taken here, not inside remote_build_tart, because everything
            # below shares state between runs: build-input/remote-input is deleted and
            # rebuilt, and resolve_configuration checks out the codesigning repository.
            # A second vm-build does all of that before it discovers it is refused, so a
            # late lock let a refused run empty the certificates directory underneath a
            # build that was already rsyncing it into its VM.
            with TartBuild.exclusive_vm_build(
                target=args.vmImage if args.vmImage is not None else TartBuild.default_vm_image_name(versions.macos_version, versions.xcode_version),
                mode='persistent' if args.persistentVM else 'ephemeral'
            ):
                remote_input_path = '{}/build-input/remote-input'.format(base_path)
                if os.path.exists(remote_input_path):
                    shutil.rmtree(remote_input_path)
                os.makedirs(remote_input_path)
                os.makedirs(remote_input_path + '/certs')
                os.makedirs(remote_input_path + '/profiles')

                resolve_configuration(
                    base_path=os.getcwd(),
                    bazel_command_line=None,
                    arguments=args,
                    additional_codesigning_output_path=remote_input_path
                )

                shutil.copyfile(args.configurationPath, remote_input_path + '/configuration.json')

                TartBuild.remote_build_tart(
                    macos_version=versions.macos_version,
                    bazel_cache_host=args.cacheHost,
                    configuration=args.configuration,
                    build_input_data_path=remote_input_path,
                    vm_image=args.vmImage,
                    override_xcode_version=args.overrideXcodeVersion,
                    ephemeral_vm=not args.persistentVM,
                    vm_cpu=args.vmCpu,
                    vm_memory=args.vmMemory
                )
        elif args.commandName == 'generate-verification-profiles':
            base_path = os.getcwd()
            remote_input_path = '{}/build-input/remote-input'.format(base_path)
            if os.path.exists(remote_input_path):
                shutil.rmtree(remote_input_path)
            os.makedirs(remote_input_path)
            os.makedirs(remote_input_path + '/certs')
            os.makedirs(remote_input_path + '/profiles')

            if os.path.exists(args.destination):
                shutil.rmtree(args.destination)
            os.makedirs(args.destination)

            resolve_configuration(
                base_path=os.getcwd(),
                bazel_command_line=None,
                arguments=args,
                additional_codesigning_output_path=remote_input_path
            )

            GenerateProfiles.generate_provisioning_profiles(source_path=remote_input_path + '/profiles', destination_path=args.destination, certs_path=args.certsPath)
        elif args.commandName == 'remote-deploy-testflight':
            env = os.environ
            if 'APPSTORE_CONNECT_USERNAME' not in env:
                print('APPSTORE_CONNECT_USERNAME environment variable is not set')
                sys.exit(1)
            if 'APPSTORE_CONNECT_PASSWORD' not in env:
                print('APPSTORE_CONNECT_PASSWORD environment variable is not set')
                sys.exit(1)

            versions = BuildEnvironmentVersions(base_path=os.getcwd())

            RemoteBuild.remote_deploy_testflight(
                darwin_containers_path=args.darwinContainers,
                darwin_containers_host=args.darwinContainersHost,
                macos_version=versions.macos_version,
                ipa_path=args.ipa,
                dsyms_path=args.dsyms,
                username=env['APPSTORE_CONNECT_USERNAME'],
                password=env['APPSTORE_CONNECT_PASSWORD']
            )
        elif args.commandName == 'remote-ipa-diff':
            versions = BuildEnvironmentVersions(base_path=os.getcwd())

            RemoteBuild.remote_ipa_diff(
                darwin_containers_path=args.darwinContainers,
                darwin_containers_host=args.darwinContainersHost,
                macos_version=versions.macos_version,
                ipa1_path=args.ipa1,
                ipa2_path=args.ipa2
            )
        elif args.commandName == 'test':
            test(bazel=bazel_path, arguments=args)
        elif args.commandName == 'query':
            query(bazel=bazel_path, arguments=args)
        elif args.commandName == 'spm':
            build_spm(bazel=bazel_path, arguments=args)
        else:
            raise Exception('Unknown command')
    except TartBuild.TartBuildError as e:
        # Refusing a second concurrent vm-build is a routine outcome, not a crash;
        # a stack trace buries the one line the user needs to act on.
        print('error: {}'.format(e), file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        pass
