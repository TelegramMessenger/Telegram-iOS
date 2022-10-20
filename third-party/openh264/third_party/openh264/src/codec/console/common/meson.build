cpp_sources = [
  'src/read_config.cpp'
]

conscomminc = [
  inc,
  console_common_inc,
]

libconsole_common = static_library('console_common', cpp_sources,
  include_directories: conscomminc,
  dependencies: deps)
