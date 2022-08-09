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

def remote_build(darwin_containers_host, bazel_cache_host, configuration, certificates_path, provisioning_profiles_path, configurationPath):
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

    macos_version = '12.5'
    image_name = 'macos-{macos_version}-xcode-{xcode_version}'.format(macos_version=macos_version, xcode_version=xcode_version)

    print('Image name: {}'.format(image_name))

    source_dir = os.path.basename(base_dir)
    buildbox_dir = 'buildbox'
    source_archive_path = '{buildbox_dir}/transient-data/source.tar'.format(buildbox_dir=buildbox_dir)

    if os.path.exists(source_archive_path):
        os.remove(source_archive_path)

    print('Compressing source code...')
    os.system('find . -type f -a -not -regex "\\." -a -not -regex ".*\\./git" -a -not -regex ".*\\./git/.*" -a -not -regex "\\./bazel-bin" -a -not -regex "\\./bazel-bin/.*" -a -not -regex "\\./bazel-out" -a -not -regex "\\./bazel-out/.*" -a -not -regex "\\./bazel-testlogs" -a -not -regex "\\./bazel-testlogs/.*" -a -not -regex "\\./bazel-telegram-ios" -a -not -regex "\\./bazel-telegram-ios/.*" -a -not -regex "\\./buildbox" -a -not -regex "\\./buildbox/.*" -a -not -regex "\\./buck-out" -a -not -regex "\\./buck-out/.*" -a -not -regex "\\./\\.buckd" -a -not -regex "\\./\\.buckd/.*" -a -not -regex "\\./build" -a -not -regex "\\./build/.*" -print0 | tar cf "{buildbox_dir}/transient-data/source.tar" --null -T -'.format(buildbox_dir=buildbox_dir))

    darwinContainers = DarwinContainers(serverAddress=darwin_containers_host, verbose=False)

    print('Opening container session...')
    with darwinContainers.workingImageSession(name=image_name) as session:
        print('Uploading data to container...')
        session_scp_upload(session=session, source_path=certificates_path, destination_path='certs')
        session_scp_upload(session=session, source_path=provisioning_profiles_path, destination_path='profiles')
        session_scp_upload(session=session, source_path=configurationPath, destination_path='configuration.json')
        session_scp_upload(session=session, source_path='{base_dir}/{buildbox_dir}/transient-data/source.tar'.format(base_dir=base_dir, buildbox_dir=buildbox_dir), destination_path='')

        guest_build_sh = '''
            mkdir telegram-ios
            cd telegram-ios
            tar -xf ../source.tar

            python3 build-system/Make/ImportCertificates.py --path $HOME/certs

            python3 build-system/Make/Make.py \\
                build \\
                --buildNumber={build_number} \\
                --configuration={configuration} \\
                --configurationPath=$HOME/configuration.json \\
                --apsEnvironment=production \\
                --provisioningProfilesPath=$HOME/profiles
        '''.format(
            build_number=build_number,
            configuration=configuration
        )
        guest_build_file_path = tempfile.mktemp()
        with open(guest_build_file_path, 'w+') as file:
            file.write(guest_build_sh)
        session_scp_upload(session=session, source_path=guest_build_file_path, destination_path='guest-build-telegram.sh')
        os.unlink(guest_build_file_path)

        print('Executing remote build...')

        if bazel_cache_host is None:
            bazel_cache_host = ''
        session_ssh(session=session, command='bash -l guest-build-telegram.sh')

        print('Retrieving build artifacts...')

        artifacts_path='{base_dir}/build/artifacts'.format(base_dir=base_dir)
        if os.path.exists(artifacts_path):
            shutil.rmtree(artifacts_path)
        os.makedirs(artifacts_path, exist_ok=True)

        session_scp_download(session=session, source_path='telegram-ios/build/artifacts/*', destination_path='{artifacts_path}/'.format(artifacts_path=artifacts_path))
        print('Artifacts have been stored at {}'.format(artifacts_path))
