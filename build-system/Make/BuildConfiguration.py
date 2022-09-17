import json
import os
import sys
import shutil
import tempfile
import plistlib

from BuildEnvironment import run_executable_with_output, check_run_system

class BuildConfiguration:
    def __init__(self,
        bundle_id,
        api_id,
        api_hash,
        team_id,
        app_center_id,
        is_internal_build,
        is_appstore_build,
        appstore_id,
        app_specific_url_scheme,
        premium_iap_product_id,
        enable_siri,
        enable_icloud
    ):
        self.bundle_id = bundle_id
        self.api_id = api_id
        self.api_hash = api_hash
        self.team_id = team_id
        self.app_center_id = app_center_id
        self.is_internal_build = is_internal_build
        self.is_appstore_build = is_appstore_build
        self.appstore_id = appstore_id
        self.app_specific_url_scheme = app_specific_url_scheme
        self.premium_iap_product_id = premium_iap_product_id
        self.enable_siri = enable_siri
        self.enable_icloud = enable_icloud

    def write_to_variables_file(self, aps_environment, path):
        string = ''
        string += 'telegram_bundle_id = "{}"\n'.format(self.bundle_id)
        string += 'telegram_api_id = "{}"\n'.format(self.api_id)
        string += 'telegram_api_hash = "{}"\n'.format(self.api_hash)
        string += 'telegram_team_id = "{}"\n'.format(self.team_id)
        string += 'telegram_app_center_id = "{}"\n'.format(self.app_center_id)
        string += 'telegram_is_internal_build = "{}"\n'.format(self.is_internal_build)
        string += 'telegram_is_appstore_build = "{}"\n'.format(self.is_appstore_build)
        string += 'telegram_appstore_id = "{}"\n'.format(self.appstore_id)
        string += 'telegram_app_specific_url_scheme = "{}"\n'.format(self.app_specific_url_scheme)
        string += 'telegram_premium_iap_product_id = "{}"\n'.format(self.premium_iap_product_id)
        string += 'telegram_aps_environment = "{}"\n'.format(aps_environment)
        string += 'telegram_enable_siri = {}\n'.format(self.enable_siri)
        string += 'telegram_enable_icloud = {}\n'.format(self.enable_icloud)
        string += 'telegram_enable_watch = True\n'

        if os.path.exists(path):
            os.remove(path)
        with open(path, 'w+') as file:
            file.write(string)


def build_configuration_from_json(path):
    if not os.path.exists(path):
        print('Could not load build configuration from {}'.format(path))
        sys.exit(1)
    with open(path) as file:
        configuration_dict = json.load(file)
        required_keys = [
            'bundle_id',
            'api_id',
            'api_hash',
            'team_id',
            'app_center_id',
            'is_internal_build',
            'is_appstore_build',
            'appstore_id',
            'app_specific_url_scheme',
            'premium_iap_product_id',
            'enable_siri',
            'enable_icloud'
        ]
        for key in required_keys:
            if key not in configuration_dict:
                print('Configuration at {} does not contain {}'.format(path, key))
        return BuildConfiguration(
            bundle_id=configuration_dict['bundle_id'],
            api_id=configuration_dict['api_id'],
            api_hash=configuration_dict['api_hash'],
            team_id=configuration_dict['team_id'],
            app_center_id=configuration_dict['app_center_id'],
            is_internal_build=configuration_dict['is_internal_build'],
            is_appstore_build=configuration_dict['is_appstore_build'],
            appstore_id=configuration_dict['appstore_id'],
            app_specific_url_scheme=configuration_dict['app_specific_url_scheme'],
            premium_iap_product_id=configuration_dict['premium_iap_product_id'],
            enable_siri=configuration_dict['enable_siri'],
            enable_icloud=configuration_dict['enable_icloud']
        )


def decrypt_codesigning_directory_recursively(source_base_path, destination_base_path, password):
    for file_name in os.listdir(source_base_path):
        source_path = source_base_path + '/' + file_name
        destination_path = destination_base_path + '/' + file_name
        if os.path.isfile(source_path):
            os.system('openssl aes-256-cbc -md md5 -k "{password}" -in "{source_path}" -out "{destination_path}" -a -d 2>/dev/null'.format(
                password=password,
                source_path=source_path,
                destination_path=destination_path
            ))
        elif os.path.isdir(source_path):
            os.makedirs(destination_path, exist_ok=True)
            decrypt_codesigning_directory_recursively(source_path, destination_path, password)


def load_codesigning_data_from_git(working_dir, repo_url, temp_key_path, branch, password, always_fetch):
    if not os.path.exists(working_dir):
        os.makedirs(working_dir, exist_ok=True)

    ssh_command = 'ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    if temp_key_path is not None:
        ssh_command += ' -i {}'.format(temp_key_path)

    encrypted_working_dir = working_dir + '/encrypted'
    if os.path.exists(encrypted_working_dir):
        if always_fetch:
            original_working_dir = os.getcwd()
            os.chdir(encrypted_working_dir)
            check_run_system('GIT_SSH_COMMAND="{ssh_command}" git fetch'.format(ssh_command=ssh_command))
            check_run_system('git checkout "{branch}"'.format(branch=branch))
            check_run_system('GIT_SSH_COMMAND="{ssh_command}" git pull'.format(ssh_command=ssh_command))
            os.chdir(original_working_dir)
    else:
        os.makedirs(encrypted_working_dir, exist_ok=True)
        original_working_dir = os.getcwd()
        os.chdir(working_dir)
        check_run_system('GIT_SSH_COMMAND="{ssh_command}" git clone --depth=1 {repo_url} -b "{branch}" "{target_path}"'.format(
            ssh_command=ssh_command,
            repo_url=repo_url,
            branch=branch,
            target_path=encrypted_working_dir
        ))
        os.chdir(original_working_dir)

    decrypted_working_dir = working_dir + '/decrypted'
    if os.path.exists(decrypted_working_dir):
        shutil.rmtree(decrypted_working_dir)
    os.makedirs(decrypted_working_dir, exist_ok=True)

    decrypt_codesigning_directory_recursively(encrypted_working_dir + '/profiles', decrypted_working_dir + '/profiles', password)
    decrypt_codesigning_directory_recursively(encrypted_working_dir + '/certs', decrypted_working_dir + '/certs', password)


def copy_profiles_from_directory(source_path, destination_path, team_id, bundle_id):
    profile_name_mapping = {
        '.SiriIntents': 'Intents',
        '.NotificationContent': 'NotificationContent',
        '.NotificationService': 'NotificationService',
        '.Share': 'Share',
        '': 'Telegram',
        '.watchkitapp': 'WatchApp',
        '.watchkitapp.watchkitextension': 'WatchExtension',
        '.Widget': 'Widget',
        '.BroadcastUpload': 'BroadcastUpload'
    }

    for file_name in os.listdir(source_path):
        file_path = source_path + '/' + file_name
        if os.path.isfile(file_path):
            if not file_path.endswith('.mobileprovision'):
                continue

            profile_data = run_executable_with_output('openssl', arguments=[
                'smime',
                '-inform',
                'der',
                '-verify',
                '-noverify',
                '-in',
                file_path
            ], decode=False, stderr_to_stdout=False, check_result=True)

            profile_dict = plistlib.loads(profile_data)
            profile_name = profile_dict['Entitlements']['application-identifier']

            if profile_name.startswith(team_id + '.' + bundle_id):
                profile_base_name = profile_name[len(team_id + '.' + bundle_id):]
                if profile_base_name in profile_name_mapping:
                    shutil.copyfile(file_path, destination_path + '/' + profile_name_mapping[profile_base_name] + '.mobileprovision')
                else:
                    print('Warning: skipping provisioning profile at {} with bundle_id {} (base_name {})'.format(file_path, profile_name, profile_base_name))


def resolve_aps_environment_from_directory(source_path, team_id, bundle_id):
    for file_name in os.listdir(source_path):
        file_path = source_path + '/' + file_name
        if os.path.isfile(file_path):
            if not file_path.endswith('.mobileprovision'):
                continue

            profile_data = run_executable_with_output('openssl', arguments=[
                'smime',
                '-inform',
                'der',
                '-verify',
                '-noverify',
                '-in',
                file_path
            ], decode=False, stderr_to_stdout=False, check_result=True)

            profile_dict = plistlib.loads(profile_data)
            profile_name = profile_dict['Entitlements']['application-identifier']

            if profile_name.startswith(team_id + '.' + bundle_id):
                profile_base_name = profile_name[len(team_id + '.' + bundle_id):]
                if profile_base_name == '':
                    if 'aps-environment' not in profile_dict['Entitlements']:
                        print('Provisioning profile at {} does not include an aps-environment entitlement'.format(file_path))
                        sys.exit(1)
                    return profile_dict['Entitlements']['aps-environment']
    return None


def copy_certificates_from_directory(source_path, destination_path):
    for file_name in os.listdir(source_path):
        file_path = source_path + '/' + file_name
        if os.path.isfile(file_path):
            if file_path.endswith('.p12') or file_path.endswith('.cer'):
                shutil.copyfile(file_path, destination_path + '/' + file_name)


class CodesigningSource:
    def __init__(self):
        pass

    def load_data(self, working_dir):
        raise Exception('Not implemented')

    def copy_profiles_to_destination(self, destination_path):
        raise Exception('Not implemented')

    def resolve_aps_environment(self):
        raise Exception('Not implemented')        

    def copy_certificates_to_destination(self, destination_path):
        raise Exception('Not implemented')


class GitCodesigningSource(CodesigningSource):
    def __init__(self, repo_url, private_key, team_id, bundle_id, codesigning_type, password, always_fetch):
        self.repo_url = repo_url
        self.private_key = private_key
        self.team_id = team_id
        self.bundle_id = bundle_id
        self.codesigning_type = codesigning_type
        self.password = password
        self.always_fetch = always_fetch

    def load_data(self, working_dir):
        self.working_dir = working_dir
        temp_key_path = None
        if self.private_key is not None:
            temp_key_path = tempfile.mktemp()
            with open(temp_key_path, 'w+') as file:
                file.write(self.private_key)
                if not self.private_key.endswith('\n'):
                    file.write('\n')
            os.chmod(temp_key_path, 0o600)

        load_codesigning_data_from_git(working_dir=self.working_dir, repo_url=self.repo_url, temp_key_path=temp_key_path, branch=self.team_id, password=self.password, always_fetch=self.always_fetch)

        if temp_key_path is not None:
            os.remove(temp_key_path)

    def copy_profiles_to_destination(self, destination_path):
        source_path = self.working_dir + '/decrypted/profiles/{}'.format(self.codesigning_type)
        copy_profiles_from_directory(source_path=source_path, destination_path=destination_path, team_id=self.team_id, bundle_id=self.bundle_id)

    def resolve_aps_environment(self):
        source_path = self.working_dir + '/decrypted/profiles/{}'.format(self.codesigning_type)
        return resolve_aps_environment_from_directory(source_path=source_path, team_id=self.team_id, bundle_id=self.bundle_id)

    def copy_certificates_to_destination(self, destination_path):
        source_path = None
        if self.codesigning_type in ['adhoc', 'appstore']:
            source_path = self.working_dir + '/decrypted/certs/distribution'
        elif self.codesigning_type == 'enterprise':
            source_path = self.working_dir + '/decrypted/certs/enterprise'
        elif self.codesigning_type == 'development':
            source_path = self.working_dir + '/decrypted/certs/development'
        else:
            raise Exception('Unknown codesigning type {}'.format(self.codesigning_type))
        copy_certificates_from_directory(source_path=source_path, destination_path=destination_path)


class DirectoryCodesigningSource(CodesigningSource):
    def __init__(self, directory_path, team_id, bundle_id):
        self.directory_path = directory_path
        self.team_id = team_id
        self.bundle_id = bundle_id

    def load_data(self, working_dir):
        pass

    def copy_profiles_to_destination(self, destination_path):
        copy_profiles_from_directory(source_path=self.directory_path + '/profiles', destination_path=destination_path, team_id=self.team_id, bundle_id=self.bundle_id)

    def resolve_aps_environment(self):
        return resolve_aps_environment_from_directory(source_path=self.directory_path + '/profiles', team_id=self.team_id, bundle_id=self.bundle_id)

    def copy_certificates_to_destination(self, destination_path):
        copy_certificates_from_directory(source_path=self.directory_path + '/certs', destination_path=destination_path)
