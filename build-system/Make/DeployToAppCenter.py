import os
import sys
import argparse
import json

from BuildEnvironment import check_run_system

def deploy_to_appcenter(args):
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
            'username',
            'app_name',
            'api_token',
        ]
        for key in required_keys:
            if key not in configuration_dict:
                print('Configuration at {} does not contain {}'.format(args.configuration, key))

        check_run_system('appcenter login --token {token}'.format(token=configuration_dict['api_token']))
        check_run_system('appcenter distribute release --app "{username}/{app_name}" -f "{ipa_path}" -g Internal'.format(
            username=configuration_dict['username'],
            app_name=configuration_dict['app_name'],
            ipa_path=args.ipa,

        ))
        if args.dsyms is not None:
            check_run_system('appcenter crashes upload-symbols --app "{username}/{app_name}" --symbol "{dsym_path}"'.format(
                username=configuration_dict['username'],
                app_name=configuration_dict['app_name'],
                dsym_path=args.dsyms
            ))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='deploy-appcenter')

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

    if len(sys.argv) < 2:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    deploy_to_appcenter(args)
