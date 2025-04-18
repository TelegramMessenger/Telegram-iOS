#!/usr/bin/python2.7

import os
import subprocess
import sys

ninja = sys.argv[1]

def call(cmd):
  subprocess.check_call(cmd, shell=True)

def append(path, line):
  with open(path, 'a') as f:
    print >>f, line

print "Hello from {platform} in {cwd}!".format(platform=sys.platform,
                                               cwd=os.getcwd())

if 'darwin' in sys.platform:
  # Get Xcode from CIPD using mac_toolchain tool.
  mac_toolchain = os.path.join(os.getcwd(), sys.argv[3])
  xcode_app_path = os.path.join(os.getcwd(), sys.argv[4])
  # See mapping of Xcode version to Xcode build version here:
  # https://chrome-infra-packages.appspot.com/p/infra_internal/ios/xcode/mac/+/
  XCODE_BUILD_VERSION = '12d4e'   # xcode 12.4
  call('rm -rf {xcode_app_path}'.format(xcode_app_path=xcode_app_path))
  call(('{mac_toolchain}/mac_toolchain install '
        '-kind mac '
        '-xcode-version {xcode_build_version} '
        '-output-dir {xcode_app_path}').format(
            mac_toolchain=mac_toolchain,
            xcode_build_version=XCODE_BUILD_VERSION,
            xcode_app_path=xcode_app_path))
  call('sudo xcode-select -switch {xcode_app_path}'.format(
      xcode_app_path=xcode_app_path))

  call('{ninja}/ninja -C skcms -k 0'.format(ninja=ninja))

elif 'linux' in sys.platform:
  # Point to clang in our clang_linux package.
  clang_linux = os.path.realpath(sys.argv[3])
  append('skcms/ninja/clang', 'cc  = {}/bin/clang  '.format(clang_linux))
  append('skcms/ninja/clang', 'cxx = {}/bin/clang++'.format(clang_linux))

  # Get an Emscripten environment all set up.
  call('git clone https://github.com/emscripten-core/emsdk.git')
  os.chdir('emsdk')
  call('./emsdk install 2.0.14')
  os.chdir('..')

  emscripten_sdk = os.path.realpath('emsdk')
  node = emscripten_sdk + '/node/14.18.2_64bit/bin/node'

  em_config = os.path.realpath(os.path.join('.', 'em_config'))
  with open(em_config, 'w') as f:
    print >>f, '''
LLVM_ROOT = '{}/upstream/bin'
BINARYEN_ROOT = '{}/upstream'
EMSCRIPTEN_ROOT = '{}/upstream/emscripten'
NODE_JS = '{}'
COMPILER_ENGINE = NODE_JS
JS_ENGINES = [NODE_JS]
  '''.format(emscripten_sdk, emscripten_sdk, emscripten_sdk, node)

  append('skcms/ninja/emscripten',
         'cc  = env EM_CONFIG={} {}/upstream/emscripten/emcc'.format(
           em_config, emscripten_sdk))
  append('skcms/ninja/emscripten',
         'cxx = env EM_CONFIG={} {}/upstream/emscripten/em++'.format(
           em_config, emscripten_sdk))
  append('skcms/ninja/emscripten',
         'node = {}'.format(node))

  call('{ninja}/ninja -C skcms -k 0'.format(ninja=ninja))

else:  # Windows
  win_toolchain = os.path.realpath(sys.argv[2])
  msvc = win_toolchain + '\\VC\\Tools\\MSVC\\14.24.28314\\'
  sdk  = win_toolchain + '\\win_sdk\\'

  os.environ['PATH'] = msvc + 'bin\\HostX64\\x64;' + os.environ['PATH']
  os.environ['INCLUDE'] = msvc + 'include;'
  os.environ['INCLUDE'] += sdk + 'Include\\10.0.17763.0\\shared;'
  os.environ['INCLUDE'] += sdk + 'Include\\10.0.17763.0\\ucrt;'
  os.environ['INCLUDE'] += sdk + 'Include\\10.0.17763.0\\um;'
  os.environ['LIB'] = msvc + 'lib\\x64;'
  os.environ['LIB'] += sdk + 'Lib\\10.0.17763.0\\um\\x64;'
  os.environ['LIB'] += sdk + 'Lib\\10.0.17763.0\\ucrt\\x64;'

  call('{ninja}\\ninja.exe -C skcms -f msvs.ninja -k 0'.format(ninja=ninja))
