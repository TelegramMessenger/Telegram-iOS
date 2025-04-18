import json
import os
import sys
import shutil
import tempfile
import plistlib
import argparse

from BuildEnvironment import run_executable_with_output, check_run_system


def get_certificate_base64():
    certificate_data = run_executable_with_output('security', arguments=['find-certificate', '-c', 'Apple Distribution: Telegram FZ-LLC (C67CF9S4VU)', '-p'])
    certificate_data = certificate_data.replace('-----BEGIN CERTIFICATE-----', '')
    certificate_data = certificate_data.replace('-----END CERTIFICATE-----', '')
    certificate_data = certificate_data.replace('\n', '')
    return certificate_data


def process_provisioning_profile(source, destination, certificate_data):
    parsed_plist = run_executable_with_output('security', arguments=['cms', '-D', '-i', source], check_result=True)
    parsed_plist_file = tempfile.mktemp()
    with open(parsed_plist_file, 'w+') as file:
        file.write(parsed_plist)

    run_executable_with_output('plutil', arguments=['-remove', 'DeveloperCertificates.0', parsed_plist_file])
    run_executable_with_output('plutil', arguments=['-insert', 'DeveloperCertificates.0', '-data', certificate_data, parsed_plist_file])
    run_executable_with_output('plutil', arguments=['-remove', 'DER-Encoded-Profile', parsed_plist_file])

    run_executable_with_output('security', arguments=['cms', '-S', '-N', 'Apple Distribution: Telegram FZ-LLC (C67CF9S4VU)', '-i', parsed_plist_file, '-o', destination])    

    os.unlink(parsed_plist_file)


def generate_provisioning_profiles(source_path, destination_path):
    certificate_data = get_certificate_base64()

    if not os.path.exists(destination_path):
        print('{} does not exits'.format(destination_path))
        sys.exit(1)

    for file_name in os.listdir(source_path):
        if file_name.endswith('.mobileprovision'):
            process_provisioning_profile(source=source_path + '/' + file_name, destination=destination_path + '/' + file_name, certificate_data=certificate_data)
