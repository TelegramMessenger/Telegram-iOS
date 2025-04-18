cpp_sources = [
  'src/d3d9_utils.cpp',
  'src/h264dec.cpp',
]

decinc = [
  inc,
  console_common_inc,
  include_directories('inc'),
]

decexe = executable('h264dec', cpp_sources,
  include_directories: decinc,
  link_with: [libdecoder, libcommon, libconsole_common],
  dependencies: deps)
