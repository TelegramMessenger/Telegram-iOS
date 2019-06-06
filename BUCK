load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config')
load('//tools:buck_defs.bzl', 'SHARED_CONFIGS')

genrule(
    name = 'openssl_libs',
    srcs = [
        'openssl/iOS/libcrypto.a',
    ],
    bash = 'mkdir -p $OUT; cp $SRCS $OUT/',
    out = 'openssl_libs',
    visibility = [
        '//submodules/MtProtoKit:...',
    ]
)

apple_library(
    name = 'openssl',
    visibility = [
        '//submodules/MtProtoKit:MtProtoKit'
    ],
    header_namespace = 'openssl',
    exported_headers = glob([
        'openssl/**/*.h',
    ]),
    exported_linker_flags = [
        '-lcrypto',
        '-L$(location :openssl_libs)',
    ],
)

apple_library(
    name = 'MtProtoKit',
    srcs = glob([
        '*.m',
        'MtProtoKit/*.m',
        'thirdparty/AFNetworking/*.m',
        'thirdparty/AsyncSocket/*.m',
    ]),
    headers = glob([
        '*.h',
        'MtProtoKit/*.h',
        'thirdparty/AFNetworking/*.h',
        'thirdparty/AsyncSocket/*.h',
    ]),
    header_namespace = 'MtProtoKit',
    exported_headers = [
        'MtProtoKit/MTTime.h',
        'MtProtoKit/MTTimer.h',
        'MtProtoKit/MTLogging.h',
        'MtProtoKit/MTEncryption.h',
        'MtProtoKit/MTInternalId.h',
        'MtProtoKit/MTQueue.h',
        'MtProtoKit/MTOutputStream.h',
        'MtProtoKit/MTInputStream.h',
        'MtProtoKit/MTSerialization.h',
        'MtProtoKit/MTExportedAuthorizationData.h',
        'MtProtoKit/MTRpcError.h',
        'MtProtoKit/MTKeychain.h',
        'MtProtoKit/MTFileBasedKeychain.h',
        'MtProtoKit/MTContext.h',
        'MtProtoKit/MTTransportScheme.h',
        'MtProtoKit/MTDatacenterTransferAuthAction.h',
        'MtProtoKit/MTDatacenterAuthAction.h',
        'MtProtoKit/MTDatacenterAuthMessageService.h',
        'MtProtoKit/MTDatacenterAddress.h',
        'MtProtoKit/MTDatacenterAddressSet.h',
        'MtProtoKit/MTDatacenterAuthInfo.h',
        'MtProtoKit/MTDatacenterSaltInfo.h',
        'MtProtoKit/MTDatacenterAddressListData.h',
        'MtProtoKit/MTProto.h',
        'MtProtoKit/MTSessionInfo.h',
        'MtProtoKit/MTTimeFixContext.h',
        'MtProtoKit/MTPreparedMessage.h',
        'MtProtoKit/MTOutgoingMessage.h',
        'MtProtoKit/MTIncomingMessage.h',
        'MtProtoKit/MTMessageEncryptionKey.h',
        'MtProtoKit/MTMessageService.h',
        'MtProtoKit/MTMessageTransaction.h',
        'MtProtoKit/MTTimeSyncMessageService.h',
        'MtProtoKit/MTRequestMessageService.h',
        'MtProtoKit/MTRequest.h',
        'MtProtoKit/MTRequestContext.h',
        'MtProtoKit/MTRequestErrorContext.h',
        'MtProtoKit/MTDropResponseContext.h',
        'MtProtoKit/MTApiEnvironment.h',
        'MtProtoKit/MTResendMessageService.h',
        'MtProtoKit/MTNetworkAvailability.h',
        'MtProtoKit/MTTransport.h',
        'MtProtoKit/MTTransportTransaction.h',
        'MtProtoKit/MTTcpTransport.h',
        'MtProtoKit/MTHttpRequestOperation.h',
        'MTAtomic.h',
        'MTBag.h',
        'MTDisposable.h',
        'MTSubscriber.h',
        'MTSignal.h',
        'MTNetworkUsageCalculationInfo.h',
        'MTNetworkUsageManager.h',
        'MTBackupAddressSignals.h',
        'thirdparty/AFNetworking/AFURLConnectionOperation.h',
        'thirdparty/AFNetworking/AFHTTPRequestOperation.h',
        'MTProxyConnectivity.h',
        'MTGzip.h',
        'MTDatacenterVerificationData.h',
        'MTPKCS.h',
    ],
    modular = True,
    configs = configs_with_config({}),
    compiler_flags = ['-w'],
    preprocessor_flags = ['-fobjc-arc'],
    visibility = ['PUBLIC'],
    deps = [
        ':openssl',
    ],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
        '$SDKROOT/System/Library/Frameworks/Security.framework',
    ],
)
