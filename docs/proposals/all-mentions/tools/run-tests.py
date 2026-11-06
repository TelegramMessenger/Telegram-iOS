#!/usr/bin/env python3
"""Run the four collective-mention XCTest targets on a chosen simulator."""
from __future__ import annotations
import argparse,fcntl,json,os,platform,runpy,subprocess,sys
from pathlib import Path
TESTS=[('submodules/TextFormat:TextFormatTests','AllMentionTests,AllMentionRateLimitTests,AllMentionScheduledDeliveryTests,AllMentionIncomingMessageTests,AllMentionDemoStorageTests,AllMentionForumTests,AllMentionMessageReuseTests,AllMentionScheduledDestinationTests'),('submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer:ChatRichTextEditorComposerTests','AllMentionComposerTests'),('Telegram:AllMentionLocalizationTests','AllMentionLocalizationTests'),('submodules/TelegramUI:AllMentionSendEffectTests','AllMentionSendEffectLifecycleTests')]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',required=True,type=Path)
    parser.add_argument('--device',required=True,help='Available iOS simulator UDID')
    parser.add_argument('--build-number',type=int,default=100044)
    a=parser.parse_args();repo=a.repo.expanduser().resolve();local=repo/'build-input/.local-allmention'
    if a.build_number<1:raise RuntimeError('Build number must be positive.')
    support=runpy.run_path(str(Path(__file__).with_name('build-demo.py')),run_name='review_build_support')
    config=local/'configuration.json';values=json.loads(config.read_text())
    if str(values['api_id'])!='0' or values['api_hash']!='' or values['bundle_id']!='org.allmention.TelegramClient':raise RuntimeError('Prepare the isolated placeholder configuration with build-demo.py first.')
    version=json.loads((repo/'versions.json').read_text())['bazel'].split(':')[0]
    arch='darwin-arm64' if platform.machine()=='arm64' else 'darwin-x86_64'
    binary=repo/'build-input'/f'bazel-{version}-{arch}';rc=local/'.bazelrc.user';wrapper=local/'bazel-pr-tests'
    if not binary.is_file() or not rc.is_file():raise RuntimeError('Run build-demo.py --execute first to prepare the official Bazel binary and configuration.')
    results=[]
    with (local/'build.lock').open('w') as lock:
        fcntl.flock(lock.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
        subprocess.run(['xcrun','simctl','bootstatus',a.device,'-b'],check=True)
        for target,classes in TESTS:
            support['check_disk'](repo,2)
            extra=['--test_arg=--destination=platform=ios_simulator,id='+a.device,'--test_filter='+classes,'--test_output=all','--cache_test_results=no']
            text='#!/usr/bin/python3\nimport os,sys\nbinary='+repr(str(binary))+'\nrc='+repr(str(rc))+"\nargs=sys.argv[1:]\nif args==['--version']:os.execv(binary,[binary,'--version'])\nif 'test' in args:\n    args=["+repr('--define=buildNumber='+str(a.build_number))+" if x=='--define=buildNumber=10000' else x for x in args]\n    args+="+repr(extra)+"\nos.execv(binary,[binary,'--nosystem_rc','--nohome_rc','--noworkspace_rc','--bazelrc='+rc,*args])\n"
            support['write_private'](wrapper,text,executable=True)
            logs=local/'pr-tests'/target.split(':')[-1];logs.mkdir(parents=True,exist_ok=True)
            command=[sys.executable,str(repo/'build-system/Make/Make.py'),'--bazel',str(wrapper),'--bazelUserRoot',str(local/'bazel-user-root'),'test','--configurationPath',str(config),'--xcodeManagedCodesigning','--target',target]
            status=support['run_build'](command,repo,logs,2,0,'')
            results.append(dict(target=target,classes=classes,exit_code=status,log=str(logs/'build.log')))
            (local/'pr-tests/results.json').write_text(json.dumps(results,indent=2)+'\n')
    return int(any(x['exit_code'] for x in results))
if __name__=='__main__':
    try:sys.exit(main())
    except (RuntimeError,OSError,ValueError,subprocess.SubprocessError) as e:print('Review tests:',e,file=sys.stderr);sys.exit(1)
