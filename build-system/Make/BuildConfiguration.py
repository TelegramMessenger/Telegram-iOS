import json
import os
import sys
import shutil
import tempfile
import plistlib

from BuildEnvironment import run_executable_with_output

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
            os.system('openssl aes-256-cbc -md md5 -k "{password}" -in "{source_path}" -out "{destination_path}" -a -d'.format(
                password=password,
                source_path=source_path,
                destination_path=destination_path
            ))
        elif os.path.isdir(source_path):
            os.makedirs(destination_path, exist_ok=True)
            decrypt_codesigning_directory_recursively(source_path, destination_path, password)


def load_provisioning_profiles_from_git(working_dir, repo_url, branch, password, always_fetch):
    if not os.path.exists(working_dir):
        os.makedirs(working_dir, exist_ok=True)

    encrypted_working_dir = working_dir + '/encrypted'
    if os.path.exists(encrypted_working_dir):
        if always_fetch:
            original_working_dir = os.getcwd()
            os.chdir(encrypted_working_dir)
            os.system('git fetch')
            os.system('git checkout "{branch}"'.format(branch=branch))
            os.system('git pull')
            os.chdir(original_working_dir)
    else:
        os.makedirs(encrypted_working_dir, exist_ok=True)
        original_working_dir = os.getcwd()
        os.chdir(working_dir)
        os.system('git clone {repo_url} -b "{branch}" "{target_path}"'.format(
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


class ProvisioningProfileSource:
    def __init__(self):
        pass

    def copy_profiles_to_destination(self, destination_path):
        raise Exception('Not implemented')


class GitProvisioningProfileSource(ProvisioningProfileSource):
    def __init__(self, working_dir, repo_url, team_id, bundle_id, profile_type, password, always_fetch):
        self.working_dir = working_dir
        self.repo_url = repo_url
        self.team_id = team_id
        self.bundle_id = bundle_id
        self.profile_type = profile_type
        self.password = password
        self.always_fetch = always_fetch

    def copy_profiles_to_destination(self, destination_path):
        load_provisioning_profiles_from_git(working_dir=self.working_dir, repo_url=self.repo_url, branch=self.team_id, password=self.password, always_fetch=self.always_fetch)
        copy_profiles_from_directory(source_path=self.working_dir + '/decrypted/profiles/{}'.format(self.profile_type), destination_path=destination_path, team_id=self.team_id, bundle_id=self.bundle_id)


class DirectoryProvisioningProfileSource(ProvisioningProfileSource):
    def __init__(self, directory_path, team_id, bundle_id):
        self.directory_path = directory_path
        self.team_id = team_id
        self.bundle_id = bundle_id

    def copy_profiles_to_destination(self, destination_path):
        profiles_path = self.directory_path
        if not os.path.exists(profiles_path):
            print('{} does not exist'.format(profiles_path))
            sys.exit(1)
        copy_profiles_from_directory(source_path=profiles_path, destination_path=destination_path, team_id=self.team_id, bundle_id=self.bundle_id)


def generate_configuration_repository(path, profile_source):
    pass
