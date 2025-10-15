import os
import sys
import argparse
import json
import re

from BuildEnvironment import run_executable_with_output

def deploy_to_firebase(args):
    if not os.path.exists(args.configuration):
        print('{} does not exist'.format(args.configuration))
        sys.exit(1)
    if not os.path.exists(args.ipa):
        print('{} does not exist'.format(args.ipa))
        sys.exit(1)
    if args.dsyms is not None and not os.path.exists(args.dsyms):
        print('{} does not exist'.format(args.dsyms))
        sys.exit(1)

    with open(args.configuration) as file:
        configuration_dict = json.load(file)
        required_keys = [
            'app_id',
            'group',
        ]
        for key in required_keys:
            if key not in configuration_dict:
                print('Configuration at {} does not contain {}'.format(args.configuration, key))
                sys.exit(1)
        
        firebase_arguments = [
            'appdistribution:distribute',
            '--app', configuration_dict['app_id'],
            '--groups', configuration_dict['group'],
            args.ipa
        ]
        
        output = run_executable_with_output(
            'firebase',
            firebase_arguments,
            use_clean_env=False,
            check_result=True
        )
        
        sharing_link_match = re.search(r'Share this release with testers who have access: (https://\S+)', output)
        if sharing_link_match:
            print(f"Sharing link: {sharing_link_match.group(1)}")
        else:
            print("No sharing link found in the output.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='deploy-firebase')

    parser.add_argument(
        '--configuration',
        required=True,
        help='Path to configuration json.'
    )
    parser.add_argument(
        '--ipa',
        required=True,
        help='Path to IPA.'
    )
    parser.add_argument(
        '--dsyms',
        required=False,
        help='Path to DSYMs.zip.'
    )
    parser.add_argument(
        '--debug',
        action='store_true',
        help='Enable debug output for firebase deploy.'
    )

    if len(sys.argv) < 2:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    deploy_to_firebase(args)
