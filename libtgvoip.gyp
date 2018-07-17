# GYP project file for TDesktop

{
    'targets': [
      {
        'target_name': 'libtgvoip',
        'type': 'static_library',
        'dependencies': [],
        'defines': [
          'WEBRTC_APM_DEBUG_DUMP=0',
          'TGVOIP_USE_DESKTOP_DSP',
        ],
        'variables': {
          'tgvoip_src_loc': '.',
          'official_build_target%': '',
          'linux_path_opus_include%': '<(DEPTH)/../../../Libraries/opus/include',
        },
        'include_dirs': [
          '<(tgvoip_src_loc)/webrtc_dsp',
          '<(linux_path_opus_include)',
        ],
        'direct_dependent_settings': {
          'include_dirs': [
            '<(tgvoip_src_loc)',
          ],
        },
        'export_dependent_settings': [],
        'sources': [
          '<(tgvoip_src_loc)/BlockingQueue.cpp',
          '<(tgvoip_src_loc)/BlockingQueue.h',
          '<(tgvoip_src_loc)/Buffers.cpp',
          '<(tgvoip_src_loc)/Buffers.h',
          '<(tgvoip_src_loc)/CongestionControl.cpp',
          '<(tgvoip_src_loc)/CongestionControl.h',
          '<(tgvoip_src_loc)/EchoCanceller.cpp',
          '<(tgvoip_src_loc)/EchoCanceller.h',
          '<(tgvoip_src_loc)/JitterBuffer.cpp',
          '<(tgvoip_src_loc)/JitterBuffer.h',
          '<(tgvoip_src_loc)/logging.cpp',
          '<(tgvoip_src_loc)/logging.h',
          '<(tgvoip_src_loc)/MediaStreamItf.cpp',
          '<(tgvoip_src_loc)/MediaStreamItf.h',
          '<(tgvoip_src_loc)/OpusDecoder.cpp',
          '<(tgvoip_src_loc)/OpusDecoder.h',
          '<(tgvoip_src_loc)/OpusEncoder.cpp',
          '<(tgvoip_src_loc)/OpusEncoder.h',
          '<(tgvoip_src_loc)/threading.h',
          '<(tgvoip_src_loc)/VoIPController.cpp',
          '<(tgvoip_src_loc)/VoIPGroupController.cpp',
          '<(tgvoip_src_loc)/VoIPController.h',
          '<(tgvoip_src_loc)/PrivateDefines.h',
          '<(tgvoip_src_loc)/VoIPServerConfig.cpp',
          '<(tgvoip_src_loc)/VoIPServerConfig.h',
          '<(tgvoip_src_loc)/audio/AudioInput.cpp',
          '<(tgvoip_src_loc)/audio/AudioInput.h',
          '<(tgvoip_src_loc)/audio/AudioOutput.cpp',
          '<(tgvoip_src_loc)/audio/AudioOutput.h',
          '<(tgvoip_src_loc)/audio/Resampler.cpp',
          '<(tgvoip_src_loc)/audio/Resampler.h',
          '<(tgvoip_src_loc)/NetworkSocket.cpp',
          '<(tgvoip_src_loc)/NetworkSocket.h',
          '<(tgvoip_src_loc)/PacketReassembler.cpp',
          '<(tgvoip_src_loc)/PacketReassembler.h',
          '<(tgvoip_src_loc)/MessageThread.cpp',
          '<(tgvoip_src_loc)/MessageThread.h',
          '<(tgvoip_src_loc)/audio/AudioIO.cpp',
          '<(tgvoip_src_loc)/audio/AudioIO.h',

          # Windows
          '<(tgvoip_src_loc)/os/windows/NetworkSocketWinsock.cpp',
          '<(tgvoip_src_loc)/os/windows/NetworkSocketWinsock.h',
          '<(tgvoip_src_loc)/os/windows/AudioInputWave.cpp',
          '<(tgvoip_src_loc)/os/windows/AudioInputWave.h',
          '<(tgvoip_src_loc)/os/windows/AudioOutputWave.cpp',
          '<(tgvoip_src_loc)/os/windows/AudioOutputWave.h',
          '<(tgvoip_src_loc)/os/windows/AudioOutputWASAPI.cpp',
          '<(tgvoip_src_loc)/os/windows/AudioOutputWASAPI.h',
          '<(tgvoip_src_loc)/os/windows/AudioInputWASAPI.cpp',
          '<(tgvoip_src_loc)/os/windows/AudioInputWASAPI.h',

          # macOS
          '<(tgvoip_src_loc)/os/darwin/AudioInputAudioUnit.cpp',
          '<(tgvoip_src_loc)/os/darwin/AudioInputAudioUnit.h',
          '<(tgvoip_src_loc)/os/darwin/AudioOutputAudioUnit.cpp',
          '<(tgvoip_src_loc)/os/darwin/AudioOutputAudioUnit.h',
          '<(tgvoip_src_loc)/os/darwin/AudioInputAudioUnitOSX.cpp',
          '<(tgvoip_src_loc)/os/darwin/AudioInputAudioUnitOSX.h',
          '<(tgvoip_src_loc)/os/darwin/AudioOutputAudioUnitOSX.cpp',
          '<(tgvoip_src_loc)/os/darwin/AudioOutputAudioUnitOSX.h',
          '<(tgvoip_src_loc)/os/darwin/AudioUnitIO.cpp',
          '<(tgvoip_src_loc)/os/darwin/AudioUnitIO.h',
          '<(tgvoip_src_loc)/os/darwin/DarwinSpecific.mm',
          '<(tgvoip_src_loc)/os/darwin/DarwinSpecific.h',

          # Linux
          '<(tgvoip_src_loc)/os/linux/AudioInputALSA.cpp',
          '<(tgvoip_src_loc)/os/linux/AudioInputALSA.h',
          '<(tgvoip_src_loc)/os/linux/AudioOutputALSA.cpp',
          '<(tgvoip_src_loc)/os/linux/AudioOutputALSA.h',
          '<(tgvoip_src_loc)/os/linux/AudioOutputPulse.cpp',
          '<(tgvoip_src_loc)/os/linux/AudioOutputPulse.h',
          '<(tgvoip_src_loc)/os/linux/AudioInputPulse.cpp',
          '<(tgvoip_src_loc)/os/linux/AudioInputPulse.h',
          '<(tgvoip_src_loc)/os/linux/AudioPulse.cpp',
          '<(tgvoip_src_loc)/os/linux/AudioPulse.h',

          # POSIX
          '<(tgvoip_src_loc)/os/posix/NetworkSocketPosix.cpp',
          '<(tgvoip_src_loc)/os/posix/NetworkSocketPosix.h',

          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/array_view.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/atomicops.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/basictypes.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/checks.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/checks.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/constructormagic.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/safe_compare.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/safe_conversions.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/safe_conversions_impl.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/sanitizer.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/stringutils.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/stringutils.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/base/type_traits.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/audio_util.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/channel_buffer.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/channel_buffer.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/fft4g.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/fft4g.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/include/audio_util.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/ring_buffer.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/ring_buffer.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/auto_corr_to_refl_coef.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/auto_correlation.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/complex_bit_reverse.c',
#          'webrtc_dsp/webrtc/common_audio/signal_processing/complex_bit_reverse_arm.S',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/complex_fft.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/complex_fft_tables.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/copy_set_operations.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/cross_correlation.c',
#          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/cross_correlation_neon.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/division_operations.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/dot_product_with_scale.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/downsample_fast.c',
#          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/downsample_fast_neon.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/energy.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/filter_ar.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/filter_ar_fast_q12.c',
#          'webrtc_dsp/webrtc/common_audio/signal_processing/filter_ar_fast_q12_armv7.S',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/filter_ma_fast_q12.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/get_hanning_window.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/get_scaling_square.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/ilbc_specific_functions.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/include/real_fft.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/include/signal_processing_library.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/include/spl_inl.h',
#          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/include/spl_inl_armv7.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/include/spl_inl_mips.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/levinson_durbin.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/lpc_to_refl_coef.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/min_max_operations.c',
#          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/min_max_operations_neon.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/randomization_functions.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/real_fft.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/refl_coef_to_lpc.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/resample.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/resample_48khz.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/resample_by_2.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/resample_by_2_internal.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/resample_by_2_internal.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/resample_fractional.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/spl_init.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/spl_inl.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/spl_sqrt.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/spl_sqrt_floor.c',
          #'webrtc_dsp/webrtc/common_audio/signal_processing/spl_sqrt_floor_arm.S',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/splitting_filter_impl.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/sqrt_of_one_minus_x_squared.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/signal_processing/vector_scaling_operations.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/sparse_fir_filter.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/sparse_fir_filter.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/wav_file.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/wav_file.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/wav_header.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/common_audio/wav_header.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/aec_common.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core.h',
#          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core_neon.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core_optimized_methods.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core_sse2.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/aec_resampler.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/aec_resampler.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/echo_cancellation.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aec/echo_cancellation.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_core.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_core.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_core_c.cc',
#          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_core_neon.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_defines.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aecm/echo_control_mobile.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/aecm/echo_control_mobile.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/analog_agc.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/analog_agc.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/digital_agc.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/digital_agc.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/gain_control.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/logging/apm_data_dumper.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/logging/apm_data_dumper.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/defines.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/noise_suppression.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/noise_suppression.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/noise_suppression_x.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/noise_suppression_x.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/ns_core.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/ns_core.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_core.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_core.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_core_c.c',
#          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_core_neon.c',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_defines.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/ns/windows_private.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/splitting_filter.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/splitting_filter.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/three_band_filter_bank.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/three_band_filter_bank.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/block_mean_calculator.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/block_mean_calculator.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator_internal.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator_wrapper.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator_wrapper.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft.h',
#          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft_neon.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft_sse2.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft_tables_common.h',
#          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft_tables_neon_sse2.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/system_wrappers/include/asm_defines.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/system_wrappers/include/compile_assert_c.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/system_wrappers/include/cpu_features_wrapper.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/system_wrappers/include/metrics.h',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/system_wrappers/source/cpu_features.cc',
          '<(tgvoip_src_loc)/webrtc_dsp/webrtc/typedefs.h',

        ],
        'libraries': [],
        'configurations': {
          'Debug': {},
          'Release': {},
        },
        'conditions': [
          [
            '"<(OS)" != "win"', {
              'sources/': [['exclude', '<(tgvoip_src_loc)/os/windows/']],
            }, {
              'sources/': [['exclude', '<(tgvoip_src_loc)/os/posix/']],
            },
          ],
          [
            '"<(OS)" != "mac"', {
              'sources/': [['exclude', '<(tgvoip_src_loc)/os/darwin/']],
            },
          ],
          [
            '"<(OS)" != "linux"', {
              'sources/': [['exclude', '<(tgvoip_src_loc)/os/linux/']],
            },
          ],
          [
            '"<(OS)" == "mac"', {
              'xcode_settings': {
                'CLANG_CXX_LANGUAGE_STANDARD': 'c++1z',
              },
              'defines': [
                'WEBRTC_POSIX',
                'WEBRTC_MAC',
                'TARGET_OS_OSX',
              ],
              'conditions': [
                [ '"<(official_build_target)" == "mac32"', {
                  'xcode_settings': {
                    'MACOSX_DEPLOYMENT_TARGET': '10.6',
                    'OTHER_CPLUSPLUSFLAGS': [ '-nostdinc++' ],
                  },
                  'include_dirs': [
                    '/usr/local/macold/include/c++/v1',
                    '<(DEPTH)/../../../Libraries/macold/openssl/include',
                  ],
                }, {
                  'xcode_settings': {
                    'MACOSX_DEPLOYMENT_TARGET': '10.8',
                    'CLANG_CXX_LIBRARY': 'libc++',
                  },
                  'include_dirs': [
                    '<(DEPTH)/../../../Libraries/openssl/include',
                  ],
                }]
              ]
            },
          ],
          [
            '"<(OS)" == "win"', {
              'msbuild_toolset': 'v141',
              'defines': [
                'NOMINMAX',
                '_USING_V110_SDK71_',
                'TGVOIP_WINXP_COMPAT'
              ],
              'libraries': [
                'winmm',
                'ws2_32',
                'kernel32',
                'user32',
              ],
              'msvs_cygwin_shell': 0,
              'msvs_settings': {
                'VCCLCompilerTool': {
                  'ProgramDataBaseFileName': '$(OutDir)\\$(ProjectName).pdb',
                  'DebugInformationFormat': '3',          # Program Database (/Zi)
                  'AdditionalOptions': [
                    '/MP',   # Enable multi process build.
                    '/EHsc', # Catch C++ exceptions only, extern C functions never throw a C++ exception.
                    '/wd4068', # Disable "warning C4068: unknown pragma"
                  ],
                  'TreatWChar_tAsBuiltInType': 'false',
                },
              },
              'msvs_external_builder_build_cmd': [
                'ninja.exe',
                '-C',
                '$(OutDir)',
                '-k0',
                '$(ProjectName)',
              ],
              'configurations': {
                'Debug': {
                  'defines': [
                    '_DEBUG',
                  ],
                  'include_dirs': [
                    '<(DEPTH)/../../../Libraries/openssl/Debug/include',
                  ],
                  'msvs_settings': {
                    'VCCLCompilerTool': {
                      'Optimization': '0',                # Disabled (/Od)
                      'RuntimeLibrary': '1',              # Multi-threaded Debug (/MTd)
                      'RuntimeTypeInfo': 'true',
                    },
                    'VCLibrarianTool': {
                      'AdditionalOptions': [
                        '/NODEFAULTLIB:LIBCMT'
                      ]
                    }
                  },
                },
                'Release': {
                  'defines': [
                    'NDEBUG',
                  ],
                  'include_dirs': [
                     '<(DEPTH)/../../../Libraries/openssl/Release/include',
                  ],
                  'msvs_settings': {
                    'VCCLCompilerTool': {
                      'Optimization': '2',                 # Maximize Speed (/O2)
                      'InlineFunctionExpansion': '2',      # Any suitable (/Ob2)
                      'EnableIntrinsicFunctions': 'true',  # Yes (/Oi)
                      'FavorSizeOrSpeed': '1',             # Favor fast code (/Ot)
                      'RuntimeLibrary': '0',               # Multi-threaded (/MT)
                      'EnableEnhancedInstructionSet': '2', # Streaming SIMD Extensions 2 (/arch:SSE2)
                      'WholeProgramOptimization': 'true',  # /GL
                    },
                    'VCLibrarianTool': {
                      'AdditionalOptions': [
                        '/LTCG',
                      ]
                    },
                  },
                },
              },
            },
          ],
          [
            '"<(OS)" == "linux"', {
              'defines': [
                'WEBRTC_POSIX',
              ],
              'conditions': [
                [ '"<!(uname -m)" == "i686"', {
                  'cflags_cc': [
                    '-msse2',
                  ],
                }]
              ],
              'direct_dependent_settings': {
                'libraries': [

                ],
              },
            },
          ],
        ],
      },
    ],
  }
