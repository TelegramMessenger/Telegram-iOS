import os
import stat
import sys
from urllib.parse import urlparse, urlunparse
import tempfile
import hashlib
import shutil

from BuildEnvironment import is_apple_silicon, resolve_executable, call_executable, run_executable_with_status, BuildEnvironmentVersions

def transform_cache_host_into_http(grpc_url):
    parsed_url = urlparse(grpc_url)
    
    new_scheme = "http"
    new_port = 8080
    
    transformed_url = urlunparse((
        new_scheme,
        f"{parsed_url.hostname}:{new_port}",
        parsed_url.path,
        parsed_url.params,
        parsed_url.query,
        parsed_url.fragment
    ))
    
    return transformed_url

def calculate_sha256(file_path):
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as file:
        # Read the file in chunks to avoid using too much memory
        for byte_block in iter(lambda: file.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def resolve_cache_host(cache_host):
    if cache_host is None:
        return None
    if cache_host.startswith("file://"):
        return None
    if "@auto" in cache_host:
        host_parts = cache_host.split("@auto")
        host_left_part = host_parts[0]
        host_right_part = host_parts[1]
        return f"{host_left_part}localhost{host_right_part}"
    return cache_host

def resolve_cache_path(cache_host_or_path, cache_dir):
    if cache_dir is not None:
        return cache_dir
    if cache_host_or_path is not None:
        if cache_host_or_path.startswith("file://"):
            return cache_host_or_path.replace("file://", "")
    return None

def cache_cas_name(digest):
    return (digest[:2], digest)

def locate_bazel(base_path, cache_host_or_path, cache_dir):
    build_input_dir = '{}/build-input'.format(base_path)
    if not os.path.isdir(build_input_dir):
        os.mkdir(build_input_dir)

    versions = BuildEnvironmentVersions(base_path=os.getcwd())
    if is_apple_silicon():
        arch = 'darwin-arm64'
    else:
        arch = 'darwin-x86_64'
    bazel_name = 'bazel-{version}-{arch}'.format(version=versions.bazel_version, arch=arch)
    bazel_path = '{}/build-input/{}'.format(base_path, bazel_name)

    resolved_cache_host = resolve_cache_host(cache_host_or_path)
    resolved_cache_path = resolve_cache_path(cache_host_or_path, cache_dir)

    if not os.path.isfile(bazel_path):
        if resolved_cache_host is not None and versions.bazel_version_sha256 is not None:
            http_cache_host = transform_cache_host_into_http(resolved_cache_host)

            with tempfile.NamedTemporaryFile(delete=True) as temp_output_file:
                call_executable([
                    'curl',
                    '-L',
                    '{cache_host}/cache/cas/{hash}'.format(
                        cache_host=http_cache_host,
                        hash=versions.bazel_version_sha256
                    ),
                    '--output',
                    temp_output_file.name
                ], check_result=False)
                test_sha256 = calculate_sha256(temp_output_file.name)
                if test_sha256 == versions.bazel_version_sha256:
                    shutil.copyfile(temp_output_file.name, bazel_path)
        elif resolved_cache_path is not None:
            (cache_cas_id, cache_cas_name) = cache_cas_name(versions.bazel_version_sha256)
            cached_path = '{}/cas/{}/{}'.format(resolved_cache_path, cache_cas_id, cache_cas_name)
            if os.path.isfile(cached_path):
                shutil.copyfile(cached_path, bazel_path)


    if os.path.isfile(bazel_path) and versions.bazel_version_sha256 is not None:
        test_sha256 = calculate_sha256(bazel_path)
        if test_sha256 != versions.bazel_version_sha256:
            print(f"Bazel at {bazel_path} does not match SHA256 {versions.bazel_version_sha256}, removing")
            os.remove(bazel_path)


    if not os.path.isfile(bazel_path):
        call_executable([
            'curl',
            '-L',
            'https://github.com/bazelbuild/bazel/releases/download/{version}/{name}'.format(
                version=versions.bazel_version,
                name=bazel_name
            ),
            '--output',
            bazel_path
        ])

        if os.path.isfile(bazel_path) and versions.bazel_version_sha256 is not None:
            test_sha256 = calculate_sha256(bazel_path)
            if test_sha256 != versions.bazel_version_sha256:
                print(f"Bazel at {bazel_path} does not match SHA256 {versions.bazel_version_sha256}, removing")
                os.remove(bazel_path)

        if resolved_cache_host is not None and versions.bazel_version_sha256 is not None:
            http_cache_host = transform_cache_host_into_http(resolved_cache_host)
            print(f"Uploading bazel@{versions.bazel_version_sha256} to bazel-remote")
            call_executable([
                'curl',
                '-X',
                'PUT',
                '-T',
                bazel_path,
                '{cache_host}/cache/cas/{hash}'.format(
                    cache_host=http_cache_host,
                    hash=versions.bazel_version_sha256
                )
            ], check_result=False)
        elif resolved_cache_path is not None:
            (cache_cas_id, cache_cas_name) = cache_cas_name(versions.bazel_version_sha256)
            cached_path = '{}/cas/{}/{}'.format(resolved_cache_path, cache_cas_id, cache_cas_name)
            os.makedirs(os.path.dirname(cached_path), exist_ok=True)
            shutil.copyfile(bazel_path, cached_path)

    if not os.access(bazel_path, os.X_OK):
        st = os.stat(bazel_path)
        os.chmod(bazel_path, st.st_mode | stat.S_IEXEC)

    return bazel_path
