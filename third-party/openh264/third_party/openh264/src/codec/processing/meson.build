cpp_sources = [
  'src/adaptivequantization/AdaptiveQuantization.cpp',
  'src/backgrounddetection/BackgroundDetection.cpp',
  'src/common/memory.cpp',
  'src/common/WelsFrameWork.cpp',
  'src/common/WelsFrameWorkEx.cpp',
  'src/complexityanalysis/ComplexityAnalysis.cpp',
  'src/denoise/denoise.cpp',
  'src/denoise/denoise_filter.cpp',
  'src/downsample/downsample.cpp',
  'src/downsample/downsamplefuncs.cpp',
  'src/imagerotate/imagerotate.cpp',
  'src/imagerotate/imagerotatefuncs.cpp',
  'src/scenechangedetection/SceneChangeDetection.cpp',
  'src/scrolldetection/ScrollDetection.cpp',
  'src/scrolldetection/ScrollDetectionFuncs.cpp',
  'src/vaacalc/vaacalcfuncs.cpp',
  'src/vaacalc/vaacalculation.cpp',
]

objs_asm = []
if cpu_family in ['x86', 'x86_64']
  asm_sources = [
    'src/x86/denoisefilter.asm',
    'src/x86/downsample_bilinear.asm',
    'src/x86/vaa.asm',
  ]
  objs_asm = asm_gen.process(asm_sources)
elif cpu_family == 'arm'
  asm_sources = [
    'src/arm/adaptive_quantization.S',
    'src/arm/down_sample_neon.S',
    'src/arm/pixel_sad_neon.S',
    'src/arm/vaa_calc_neon.S',
  ]
  if use_asm_gen
    objs_asm = asm_gen.process(asm_sources)
  else
    cpp_sources += asm_sources
  endif
elif cpu_family == 'aarch64'
  asm_sources = [
	'src/arm64/adaptive_quantization_aarch64_neon.S',
	'src/arm64/down_sample_aarch64_neon.S',
	'src/arm64/pixel_sad_aarch64_neon.S',
	'src/arm64/vaa_calc_aarch64_neon.S',
  ]
  if use_asm_gen
    objs_asm = asm_gen.process(asm_sources)
  else
    cpp_sources += asm_sources
  endif
else
  error('Unsupported cpu family @0@'.format(cpu_family))
endif

libprocessing = static_library('processing', cpp_sources, objs_asm,
  include_directories: [inc, processing_inc, casm_inc],
  dependencies: deps)
