import os
import sys
import argparse
import json

from BuildEnvironment import check_run_system

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

        debug_flag = "--debug" if args.debug else ""
        command = 'firebase appdistribution:distribute --app {app_id} --groups "{group}" {debug_flag}'.format(
            app_id=configuration_dict['app_id'],
            group=configuration_dict['group'],
            debug_flag=debug_flag
        )
            
        command += ' "{ipa_path}"'.format(ipa_path=args.ipa)
        
        check_run_system(command)


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
