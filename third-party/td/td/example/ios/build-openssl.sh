#!/bin/sh
cd $(dirname $0)

git clone https://github.com/beeware/Python-Apple-support
cd Python-Apple-support
git checkout 6f43aba0ddd5a9f52f39775d0141bd4363614020 || exit 1
git reset --hard || exit 1
git apply ../Python-Apple-support.patch || exit 1
cd ..

platforms="macOS iOS watchOS tvOS visionOS"

for platform in $platforms;
do
  if [[ $platform = "macOS" ]]; then
    simulators="0"
  else
    simulators="0 1"
  fi

  for simulator in $simulators;
  do
    if [[ $simulator = "1" ]]; then
      platform="${platform}-simulator"
    fi
    echo $platform
    cd Python-Apple-support
    #NB: -j will fail
    make OpenSSL-$platform || exit 1
    cd ..
    rm -rf third_party/openssl/$platform || exit 1
    mkdir -p third_party/openssl/$platform/lib || exit 1
    cp ./Python-Apple-support/merge/$platform/openssl/lib/libcrypto.a third_party/openssl/$platform/lib/ || exit 1
    cp ./Python-Apple-support/merge/$platform/openssl/lib/libssl.a third_party/openssl/$platform/lib/ || exit 1
    cp -r ./Python-Apple-support/merge/$platform/openssl/include/ third_party/openssl/$platform/include || exit 1
  done
done
