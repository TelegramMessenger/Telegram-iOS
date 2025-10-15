#!/bin/python3

import argparse
import os
import sys
import json
import hashlib
import base64
import requests

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            data = f.read(1024 * 64)
            if not data:
                break
            h.update(data)
    return h.hexdigest()

def init_build(host, token, files, channel):
    url = host.rstrip('/') + '/upload/init'
    headers = {"Authorization": "Bearer " + token}
    payload = {"files": files, "channel": channel}
    r = requests.post(url, json=payload, headers=headers, timeout=30)
    r.raise_for_status()
    return r.json()

def upload_file(path, upload_info):
    url = upload_info.get('url')
    headers = dict(upload_info.get('headers', {}))
    
    size = os.path.getsize(path)
    headers['Content-Length'] = str(size)

    print('Uploading', path)
    with open(path, 'rb') as f:
        r = requests.put(url, data=f, headers=headers, timeout=900)
    if r.status_code != 200:
        print('Upload failed', r.status_code)
        print(r.text[:500])
        r.raise_for_status()

def commit_build(host, token, build_id):
    url = host.rstrip('/') + '/upload/commit'
    headers = {"Authorization": "Bearer " + token}
    r = requests.post(url, json={"buildId": build_id}, headers=headers, timeout=900)
    if r.status_code != 200:
        print('Commit failed', r.status_code)
        print(r.text[:500])
        r.raise_for_status()
    return r.json()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='deploy-build')
    parser.add_argument('--ipa', required=True, help='Path to IPA')
    parser.add_argument('--dsyms', help='Path to dSYMs.zip')
    parser.add_argument('--configuration', required=True, help='Path to JSON config')
    args = parser.parse_args()
    
    if not os.path.exists(args.configuration):
        print('{} does not exist'.format(args.configuration))
        sys.exit(1)
    if not os.path.exists(args.ipa):
        print('{} does not exist'.format(args.ipa))
        sys.exit(1)
    if args.dsyms is not None and not os.path.exists(args.dsyms):
        print('{} does not exist'.format(args.dsyms))
        sys.exit(1)

    try:
        with open(args.configuration, 'r') as f:
            config = json.load(f)
    except Exception as e:
        print('Failed to read configuration:', e)
        sys.exit(1)

    host = config.get('host')
    token = config.get('auth_token')
    channel = config.get('channel')
    if not host or not token or not channel:
        print('Invalid configuration')
        sys.exit(1)
    ipa_path = args.ipa
    dsym_path = args.dsyms

    ipa_sha = sha256_file(ipa_path)
    files = {
        'ipa': {
            'filename': os.path.basename(ipa_path),
            'size': os.path.getsize(ipa_path),
            'sha256': ipa_sha,
        }
    }
    if dsym_path:
        dsym_sha = sha256_file(dsym_path)
        files['dsym'] = {
            'filename': os.path.basename(dsym_path),
            'size': os.path.getsize(dsym_path),
            'sha256': dsym_sha,
        }

    print('Init build')
    init = init_build(host, token, files, channel)
    build_id = init.get('build_id')
    urls = init.get('upload_urls', {})
    if not build_id:
        print('No build_id')
        sys.exit(1)

    upload_file(ipa_path, urls.get('ipa', {}))
    if dsym_path and 'dsym' in urls:
        upload_file(dsym_path, urls.get('dsym', {}))

    print('Commit build')
    result = commit_build(host, token, build_id)
    
    print('Done! Install page:', result.get('install_page_url'))
