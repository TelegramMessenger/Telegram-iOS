import os
import sys
import argparse

from BuildEnvironment import run_executable_with_output

def import_certificates(certificatesPath):
    if not os.path.exists(certificatesPath):
        print('{} does not exist'.format(certificatesPath))
        sys.exit(1)

    keychain_name = 'temp.keychain'
    keychain_password = 'secret'

    existing_keychains = run_executable_with_output('security', arguments=['list-keychains'], check_result=True)
    if keychain_name in existing_keychains:
        run_executable_with_output('security', arguments=['delete-keychain'], check_result=True)

    run_executable_with_output('security', arguments=[
        'create-keychain',
        '-p',
        keychain_password,
        keychain_name
    ], check_result=True)

    existing_keychains = run_executable_with_output('security', arguments=['list-keychains', '-d', 'user'])
    existing_keychains.replace('"', '')

    run_executable_with_output('security', arguments=[
        'list-keychains',
        '-d',
        'user',
        '-s',
        keychain_name,
        existing_keychains
    ], check_result=True)

    run_executable_with_output('security', arguments=['set-keychain-settings', keychain_name])
    run_executable_with_output('security', arguments=['unlock-keychain', '-p', keychain_password, keychain_name])

    for file_name in os.listdir(certificatesPath):
        file_path = certificatesPath + '/' + file_name
        if file_path.endswith('.p12') or file_path.endswith('.cer'):
            run_executable_with_output('security', arguments=[
                'import',
                file_path,
                '-k',
                keychain_name,
                '-P',
                '',
                '-T',
                '/usr/bin/codesign',
                '-T',
                '/usr/bin/security'
            ], check_result=False)

    run_executable_with_output('security', arguments=[
        'import',
        'build-system/AppleWWDRCAG3.cer',
        '-k',
        keychain_name,
        '-P',
        '',
        '-T',
        '/usr/bin/codesign',
        '-T',
        '/usr/bin/security'
    ], check_result=False)

    run_executable_with_output('security', arguments=[
        'set-key-partition-list',
        '-S',
        'apple-tool:,apple:',
        '-k',
        keychain_password,
        keychain_name
    ], check_result=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='build')

    parser.add_argument(
        '--path',
        required=True,
        help='Path to certificates.'
    )

    if len(sys.argv) < 2:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    import_certificates(args.path)
