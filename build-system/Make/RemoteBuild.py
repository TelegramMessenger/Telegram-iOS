import os
import sys
import json
import shutil
import shlex
import tempfile

from BuildEnvironment import run_executable_with_output

def session_scp_upload(session, source_path, destination_path):
    scp_command = 'scp -i {privateKeyPath} -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr {source_path} containerhost@"{ipAddress}":{destination_path}'.format(
        privateKeyPath=session.privateKeyPath,
        ipAddress=session.ipAddress,
        source_path=shlex.quote(source_path),
        destination_path=shlex.quote(destination_path)
    )
    if os.system(scp_command) != 0:
        print('Command {} finished with a non-zero status'.format(scp_command))

def session_scp_download(session, source_path, destination_path):
    scp_command = 'scp -i {privateKeyPath} -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr containerhost@"{ipAddress}":{source_path} {destination_path}'.format(
        privateKeyPath=session.privateKeyPath,
        ipAddress=session.ipAddress,
        source_path=shlex.quote(source_path),
        destination_path=shlex.quote(destination_path)
    )
    if os.system(scp_command) != 0:
        print('Command {} finished with a non-zero status'.format(scp_command))

def session_ssh(session, command):
    ssh_command = 'ssh -i {privateKeyPath} -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null containerhost@"{ipAddress}" -o ServerAliveInterval=60 -t "{command}"'.format(
        privateKeyPath=session.privateKeyPath,
        ipAddress=session.ipAddress,
        command=command
    )
    return os.system(ssh_command)

def remote_build(darwin_containers_host, bazel_cache_host, configuration, build_input_data_path):
    macos_version = '12.5'

    from darwin_containers import DarwinContainers

    base_dir = os.getcwd()

    configuration_path = 'versions.json'
    xcode_version = ''
    with open(configuration_path) as file:
        configuration_dict = json.load(file)
        if configuration_dict['xcode'] is None:
            raise Exception('Missing xcode version in {}'.format(configuration_path))
        xcode_version = configuration_dict['xcode']

    print('Xcode version: {}'.format(xcode_version))

    commit_count = run_executable_with_output('git', [
        'rev-list',
        '--count',
        'HEAD'
    ])

    build_number_offset = 0
    with open('build_number_offset') as file:
        build_number_offset = int(file.read())

    build_number = build_number_offset + int(commit_count)
    print('Build number: {}'.format(build_number))

    image_name = 'macos-{macos_version}-xcode-{xcode_version}'.format(macos_version=macos_version, xcode_version=xcode_version)

    print('Image name: {}'.format(image_name))

    source_dir = os.path.basename(base_dir)
    buildbox_dir = 'buildbox'

    transient_data_dir = '{}/transient-data'.format(buildbox_dir)
    os.makedirs(transient_data_dir, exist_ok=True)

    source_archive_path = '{buildbox_dir}/transient-data/source.tar'.format(buildbox_dir=buildbox_dir)

    if os.path.exists(source_archive_path):
        os.remove(source_archive_path)

    print('Compressing source code...')
    os.system('find . -type f -a -not -regex "\\." -a -not -regex ".*\\./git" -a -not -regex ".*\\./git/.*" -a -not -regex "\\./bazel-bin" -a -not -regex "\\./bazel-bin/.*" -a -not -regex "\\./bazel-out" -a -not -regex "\\./bazel-out/.*" -a -not -regex "\\./bazel-testlogs" -a -not -regex "\\./bazel-testlogs/.*" -a -not -regex "\\./bazel-telegram-ios" -a -not -regex "\\./bazel-telegram-ios/.*" -a -not -regex "\\./buildbox" -a -not -regex "\\./buildbox/.*" -a -not -regex "\\./buck-out" -a -not -regex "\\./buck-out/.*" -a -not -regex "\\./\\.buckd" -a -not -regex "\\./\\.buckd/.*" -a -not -regex "\\./build" -a -not -regex "\\./build/.*" -print0 | tar cf "{buildbox_dir}/transient-data/source.tar" --null -T -'.format(buildbox_dir=buildbox_dir))

    darwinContainers = DarwinContainers(serverAddress=darwin_containers_host, verbose=False)

    print('Opening container session...')
    with darwinContainers.workingImageSession(name=image_name) as session:
        print('Uploading data to container...')
        session_scp_upload(session=session, source_path=build_input_data_path, destination_path='telegram-build-input')
        session_scp_upload(session=session, source_path='{base_dir}/{buildbox_dir}/transient-data/source.tar'.format(base_dir=base_dir, buildbox_dir=buildbox_dir), destination_path='')

        guest_build_sh = '''
            set -x
            set -e

            mkdir /Users/Shared/telegram-ios
            cd /Users/Shared/telegram-ios

            tar -xf $HOME/source.tar

            python3 build-system/Make/ImportCertificates.py --path $HOME/telegram-build-input/certs

        '''

        guest_build_sh += 'python3 build-system/Make/Make.py \\'
        if bazel_cache_host is not None:
            guest_build_sh += '--cacheHost="{}" \\'.format(bazel_cache_host)
        guest_build_sh += 'build \\'
        guest_build_sh += ''
        guest_build_sh += '--buildNumber={} \\'.format(build_number)
        guest_build_sh += '--configuration={} \\'.format(configuration)
        guest_build_sh += '--configurationPath=$HOME/telegram-build-input/configuration.json \\'
        guest_build_sh += '--codesigningInformationPath=$HOME/telegram-build-input \\'
        guest_build_sh += '--outputBuildArtifactsPath=/Users/Shared/telegram-ios/build/artifacts \\'

        guest_build_file_path = tempfile.mktemp()
        with open(guest_build_file_path, 'w+') as file:
            file.write(guest_build_sh)
        session_scp_upload(session=session, source_path=guest_build_file_path, destination_path='guest-build-telegram.sh')
        os.unlink(guest_build_file_path)

        print('Executing remote build...')

        session_ssh(session=session, command='bash -l guest-build-telegram.sh')

        print('Retrieving build artifacts...')

        artifacts_path='{base_dir}/build/artifacts'.format(base_dir=base_dir)
        if os.path.exists(artifacts_path):
            shutil.rmtree(artifacts_path)
        os.makedirs(artifacts_path, exist_ok=True)

        session_scp_download(session=session, source_path='/Users/Shared/telegram-ios/build/artifacts/*', destination_path='{artifacts_path}/'.format(artifacts_path=artifacts_path))

        if os.path.exists(artifacts_path + '/Telegram.ipa'):
            print('Artifacts have been stored at {}'.format(artifacts_path))
        else:
            print('Telegram.ipa not found')
            sys.exit(1)

def remote_deploy_testflight(darwin_containers_host, ipa_path, dsyms_path, username, password):
    macos_version = '12.5'

    from darwin_containers import DarwinContainers

    configuration_path = 'versions.json'
    xcode_version = ''
    with open(configuration_path) as file:
        configuration_dict = json.load(file)
        if configuration_dict['xcode'] is None:
            raise Exception('Missing xcode version in {}'.format(configuration_path))
        xcode_version = configuration_dict['xcode']

    print('Xcode version: {}'.format(xcode_version))

    image_name = 'macos-{macos_version}-xcode-{xcode_version}'.format(macos_version=macos_version, xcode_version=xcode_version)

    print('Image name: {}'.format(image_name))

    darwinContainers = DarwinContainers(serverAddress=darwin_containers_host, verbose=False)

    print('Opening container session...')
    with darwinContainers.workingImageSession(name=image_name) as session:
        print('Uploading data to container...')
        session_scp_upload(session=session, source_path=ipa_path, destination_path='')
        session_scp_upload(session=session, source_path=dsyms_path, destination_path='')

        guest_upload_sh = '''
            set -e

            export DELIVER_ITMSTRANSPORTER_ADDITIONAL_UPLOAD_PARAMETERS="-t DAV"
            FASTLANE_PASSWORD="{password}" xcrun altool --upload-app --type ios --file "Telegram.ipa" --username "{username}" --password "@env:FASTLANE_PASSWORD"
        '''.format(username=username, password=password)

        guest_upload_file_path = tempfile.mktemp()
        with open(guest_upload_file_path, 'w+') as file:
            file.write(guest_upload_sh)
        session_scp_upload(session=session, source_path=guest_upload_file_path, destination_path='guest-upload-telegram.sh')
        os.unlink(guest_upload_file_path)

        print('Executing remote upload...')
        session_ssh(session=session, command='bash -l guest-upload-telegram.sh')

def remote_ipa_diff(darwin_containers_host, ipa1_path, ipa2_path):
    macos_version = '12.5'

    from darwin_containers import DarwinContainers

    configuration_path = 'versions.json'
    xcode_version = ''
    with open(configuration_path) as file:
        configuration_dict = json.load(file)
        if configuration_dict['xcode'] is None:
            raise Exception('Missing xcode version in {}'.format(configuration_path))
        xcode_version = configuration_dict['xcode']

    print('Xcode version: {}'.format(xcode_version))

    image_name = 'macos-{macos_version}-xcode-{xcode_version}'.format(macos_version=macos_version, xcode_version=xcode_version)

    print('Image name: {}'.format(image_name))

    darwinContainers = DarwinContainers(serverAddress=darwin_containers_host, verbose=False)

    print('Opening container session...')
    with darwinContainers.workingImageSession(name=image_name) as session:
        print('Uploading data to container...')
        session_scp_upload(session=session, source_path='tools/ipadiff.py', destination_path='ipadiff.py')
        session_scp_upload(session=session, source_path='tools/main.cpp', destination_path='main.cpp')
        session_scp_upload(session=session, source_path=ipa1_path, destination_path='ipa1.ipa')
        session_scp_upload(session=session, source_path=ipa2_path, destination_path='ipa2.ipa')

        guest_upload_sh = '''
            set -e

            python3 ipadiff.py ipa1.ipa ipa2.ipa
            echo $? > result.txt
        '''

        guest_upload_file_path = tempfile.mktemp()
        with open(guest_upload_file_path, 'w+') as file:
            file.write(guest_upload_sh)
        session_scp_upload(session=session, source_path=guest_upload_file_path, destination_path='guest-ipa-diff.sh')
        os.unlink(guest_upload_file_path)

        print('Executing remote ipa-diff...')
        session_ssh(session=session, command='bash -l guest-ipa-diff.sh')
        guest_result_path = tempfile.mktemp()
        session_scp_download(session=session, source_path='result.txt', destination_path=guest_result_path)
        guest_result = ''
        with open(guest_result_path, 'r') as file:
            guest_result = file.read().rstrip()
        os.unlink(guest_result_path)

        if guest_result != '0':
            sys.exit(1)

