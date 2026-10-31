"""Re-signs the fake-codesigning profiles with a fresh ExpirationDate.

rules_apple refuses a profile whose ExpirationDate is in the past, and the checked-in fake profiles
expire. Each profile is decoded, given new dates, and signed again with SelfSigned.p12 in place.
Usage: python3 RefreshFakeProfiles.py <fake-codesigning dir>
"""

import os
import sys
import tempfile
import datetime

from BuildEnvironment import run_executable_with_output
from GenerateProfiles import setup_temp_keychain, cleanup_temp_keychain


def signing_identity_from_certificate(cer_path):
    # Read from the DER certificate rather than the p12, which needs OpenSSL 3's -legacy and fails under LibreSSL.
    subject = run_executable_with_output('openssl', arguments=['x509', '-inform', 'DER', '-in', cer_path, '-noout', '-subject', '-nameopt', 'oneline,-esc_msb'], stderr_to_stdout=False, check_result=True)
    if 'CN = ' in subject:
        return subject.split('CN = ')[-1].split(',')[0].strip()
    return None


def refresh_profiles(codesigning_path):
    p12_path = os.path.join(codesigning_path, 'certs', 'SelfSigned.p12')
    profiles_path = os.path.join(codesigning_path, 'profiles')

    signing_identity = signing_identity_from_certificate(os.path.join(codesigning_path, 'certs', 'Public.cer'))
    if not signing_identity:
        print('Could not extract signing identity from Public.cer')
        sys.exit(1)

    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    creation_date = now.strftime('%Y-%m-%dT%H:%M:%SZ')
    expiration_date = (now + datetime.timedelta(days=365)).strftime('%Y-%m-%dT%H:%M:%SZ')

    keychain_name = setup_temp_keychain(p12_path)
    try:
        for file_name in sorted(os.listdir(profiles_path)):
            if not file_name.endswith('.mobileprovision'):
                continue
            profile_path = os.path.join(profiles_path, file_name)
            parsed_plist = run_executable_with_output('security', arguments=['cms', '-D', '-i', profile_path], stderr_to_stdout=False, check_result=True)
            plist_file = tempfile.mktemp()
            with open(plist_file, 'w+') as file:
                file.write(parsed_plist)

            run_executable_with_output('plutil', arguments=['-replace', 'CreationDate', '-date', creation_date, plist_file], check_result=True)
            run_executable_with_output('plutil', arguments=['-replace', 'ExpirationDate', '-date', expiration_date, plist_file], check_result=True)
            # The DER copy carries the old dates and signature; it is optional, so drop it.
            run_executable_with_output('plutil', arguments=['-remove', 'DER-Encoded-Profile', plist_file], check_result=False)

            os.unlink(profile_path)
            run_executable_with_output('security', arguments=[
                'cms', '-S', '-k', keychain_name, '-N', signing_identity, '-i', plist_file, '-o', profile_path
            ], check_result=True)
            os.unlink(plist_file)
            print('Refreshed {} (expires {})'.format(file_name, expiration_date))
    finally:
        cleanup_temp_keychain(keychain_name)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Usage: RefreshFakeProfiles.py <fake-codesigning dir>')
        sys.exit(1)
    refresh_profiles(os.path.abspath(sys.argv[1]))
