FROM --platform=linux/amd64 ubuntu:24.04 AS build

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq default-jdk g++ git gperf make perl php-cli unzip wget && rm -rf /var/lib/apt/lists/*

WORKDIR /home

ARG ANDROID_NDK_VERSION=23.2.8568313
COPY ./check-environment.sh ./fetch-sdk.sh ./
RUN ./fetch-sdk.sh SDK "$ANDROID_NDK_VERSION"

ARG OPENSSL_VERSION=OpenSSL_1_1_1w
ARG BUILD_SHARED_OPENSSL_LIBS=
COPY ./build-openssl.sh ./
RUN ./build-openssl.sh SDK "$ANDROID_NDK_VERSION" openssl "$OPENSSL_VERSION" "$BUILD_SHARED_OPENSSL_LIBS"

ADD "https://api.github.com/repos/tdlib/td/git/refs/heads/master" version.json
ARG COMMIT_HASH=master
RUN git clone https://github.com/tdlib/td.git && cd td && git checkout "$COMMIT_HASH"
RUN cd td && git merge-base --is-ancestor 872d8ebd3ba9d922169839e6a24cee08b02b328a "$COMMIT_HASH"

ARG ANDROID_STL=c++_static
ARG TDLIB_INTERFACE=Java
RUN td/example/android/build-tdlib.sh SDK "$ANDROID_NDK_VERSION" openssl "$ANDROID_STL" "$TDLIB_INTERFACE" && rm -rf td/example/android/build-*


FROM scratch

COPY --from=build /home/td/example/android/tdlib/tdlib* /
