#!/bin/bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Tests implemented in bash. These typically will run checks about the source
# code rather than the compiled one.

MYDIR=$(dirname $(realpath "$0"))

set -u

test_includes() {
  local ret=0
  local f
  for f in $(git ls-files | grep -E '(\.cc|\.cpp|\.h)$'); do
    if [ ! -e "$f" ]; then
      continue
    fi
    # Check that the full paths to the public headers are not used, since users
    # of the library will include the library as: #include "jxl/foobar.h".
    if grep -i -H -n -E '#include\s*[<"]lib/include/jxl' "$f" >&2; then
      echo "Don't add \"include/\" to the include path of public headers." >&2
      ret=1
    fi

    if [[ "${f#third_party/}" == "$f" ]]; then
      # $f is not in third_party/

      # Check that local files don't use the full path to third_party/
      # directory since the installed versions will not have that path.
      # Add an exception for third_party/dirent.h.
      if grep -v -F 'third_party/dirent.h' "$f" | \
          grep -i -H -n -E '#include\s*[<"]third_party/' >&2 &&
          [[ $ret -eq 0 ]]; then
        cat >&2 <<EOF
$f: Don't add third_party/ to the include path of third_party projects. This \
makes it harder to use installed system libraries instead of the third_party/ \
ones.
EOF
        ret=1
      fi
    fi

  done
  return ${ret}
}

test_include_collision() {
  local ret=0
  local f
  for f in $(git ls-files | grep -E '^lib/include/'); do
    if [ ! -e "$f" ]; then
      continue
    fi
    local base=${f#lib/include/}
    if [[ -e "lib/${base}" ]]; then
      echo "$f: Name collision, both $f and lib/${base} exist." >&2
      ret=1
    fi
  done
  return ${ret}
}

test_copyright() {
  local ret=0
  local f
  for f in $(
      git ls-files | grep -E \
      '(Dockerfile.*|\.c|\.cc|\.cpp|\.gni|\.h|\.java|\.sh|\.m|\.py|\.ui|\.yml)$'); do
    if [ ! -e "$f" ]; then
      continue
    fi
    if [[ "${f#third_party/}" == "$f" ]]; then
      # $f is not in third_party/
      if ! head -n 10 "$f" |
          grep -F 'Copyright (c) the JPEG XL Project Authors.' >/dev/null ; then
        echo "$f: Missing Copyright blob near the top of the file." >&2
        ret=1
      fi
      if ! head -n 10 "$f" |
          grep -F 'Use of this source code is governed by a BSD-style' \
            >/dev/null ; then
        echo "$f: Missing License blob near the top of the file." >&2
        ret=1
      fi
    fi
  done
  return ${ret}
}

# Check that we don't use "%zu" or "%zd" in format string for size_t.
test_printf_size_t() {
  local ret=0
  if grep -n -E '%[0-9]*z[udx]' \
      $(git ls-files | grep -E '(\.c|\.cc|\.cpp|\.h)$'); then
    echo "Don't use '%zu' or '%zd' in a format string, instead use " \
      "'%\" PRIuS \"' or '%\" PRIdS \"'." >&2
    ret=1
  fi

  if grep -n -E 'gtest\.h' \
      $(git ls-files | grep -E '(\.c|\.cc|\.cpp|\.h)$' | grep -v -F /testing.h); then
    echo "Don't include gtest directly, instead include 'testing.h'. " >&2
    ret=1
  fi

  if grep -n -E 'gmock\.h' \
      $(git ls-files | grep -E '(\.c|\.cc|\.cpp|\.h)$' | grep -v -F /testing.h); then
    echo "Don't include gmock directly, instead include 'testing.h'. " >&2
    ret=1
  fi

  local f
  for f in $(git ls-files | grep -E "\.cc$" | xargs grep 'PRI[udx]S' |
      cut -f 1 -d : | uniq); do
    if [ ! -e "$f" ]; then
      continue
    fi
    if ! grep -F printf_macros.h "$f" >/dev/null; then
      echo "$f: Add lib/jxl/base/printf_macros.h for PRI.S, or use other " \
        "types for code outside lib/jxl library." >&2
      ret=1
    fi
  done

  for f in $(git ls-files | grep -E "\.h$" | grep -v -E '(printf_macros\.h|testing\.h)' |
      xargs grep -n 'PRI[udx]S'); do
    # Having PRIuS / PRIdS in a header file means that printf_macros.h may
    # be included before a system header, in particular before gtest headers.
    # those may re-define PRIuS unconditionally causing a compile error.
    echo "$f: Don't use PRI.S in header files. Sorry."
    ret=1
  done

  return ${ret}
}

# Check that "dec_" code doesn't depend on "enc_" headers.
test_dec_enc_deps() {
  local ret=0
  local f
  for f in $(git ls-files | grep -E '/dec_'); do
    if [ ! -e "$f" ]; then
      continue
    fi
    if [[ "${f#third_party/}" == "$f" ]]; then
      # $f is not in third_party/
      if grep -n -H -E "#include.*/enc_" "$f" >&2; then
        echo "$f: Don't include \"enc_*\" files from \"dec_*\" files." >&2
        ret=1
      fi
    fi
  done
  return ${ret}
}

# Check for git merge conflict markers.
test_merge_conflict() {
  local ret=0
  TEXT_FILES='(\.cc|\.cpp|\.h|\.sh|\.m|\.py|\.md|\.txt|\.cmake)$'
  for f in $(git ls-files | grep -E "${TEXT_FILES}"); do
    if [ ! -e "$f" ]; then
      continue
    fi
    if grep -E '^<<<<<<< ' "$f"; then
      echo "$f: Found git merge conflict marker. Please resolve." >&2
      ret=1
    fi
  done
  return ${ret}
}

# Check that the library and the package have the same version. This prevents
# accidentally having them out of sync.
get_version() {
  local varname=$1
  local line=$(grep -F "set(${varname} " lib/CMakeLists.txt | head -n 1)
  [[ -n "${line}" ]]
  line="${line#set(${varname} }"
  line="${line%)}"
  echo "${line}"
}

test_version() {
  local major=$(get_version JPEGXL_MAJOR_VERSION)
  local minor=$(get_version JPEGXL_MINOR_VERSION)
  local patch=$(get_version JPEGXL_PATCH_VERSION)
  # Check that the version is not empty
  if [[ -z "${major}${minor}${patch}" ]]; then
    echo "Couldn't parse version from CMakeLists.txt" >&2
    return 1
  fi
  local pkg_version=$(head -n 1 debian/changelog)
  # Get only the part between the first "jpeg-xl (" and the following ")".
  pkg_version="${pkg_version#jpeg-xl (}"
  pkg_version="${pkg_version%%)*}"
  if [[ -z "${pkg_version}" ]]; then
    echo "Couldn't parse version from debian package" >&2
    return 1
  fi

  local lib_version="${major}.${minor}.${patch}"
  lib_version="${lib_version%.0}"
  if [[ "${pkg_version}" != "${lib_version}"* ]]; then
    echo "Debian package version (${pkg_version}) doesn't match library" \
      "version (${lib_version})." >&2
    return 1
  fi
  return 0
}

# Check that the SHA versions in deps.sh matches the git submodules.
test_deps_version() {
  while IFS= read -r line; do
    if [[ "${line:0:10}" != "[submodule" ]]; then
      continue
    fi
    line="${line#[submodule \"}"
    line="${line%\"]}"
    local varname=$(tr '[:lower:]' '[:upper:]' <<< "${line}")
    varname="${varname/\//_}"
    if ! grep -F "${varname}=" deps.sh >/dev/null; then
      # Ignoring submodule not in deps.sh
      continue
    fi
    local deps_sha=$(grep -F "${varname}=" deps.sh | cut -f 2 -d '"')
    [[ -n "${deps_sha}" ]]
    local git_sha=$(git ls-tree -r HEAD "${line}" | cut -f 1 | cut -f 3 -d ' ')
    if [[ "${deps_sha}" != "${git_sha}" ]]; then
      cat >&2 <<EOF
deps.sh: SHA for project ${line} is at ${deps_sha} but the git submodule is at
${git_sha}. Please update deps.sh

If you did not intend to change the submodule's SHA value, it is possible that
you accidentally included this change in your commit after a rebase or checkout
without running "git submodule --init". To revert the submodule change run from
the top checkout directory:

  git -C ${line} checkout ${deps_sha}
  git commit --amend ${line}

EOF
      return 1
    fi
  done < .gitmodules
}

# Make sure that all the Fields objects are fuzzed directly.
test_fuzz_fields() {
  local ret=0
  # List all the classes of the form "ClassName : public Fields".
  # This doesn't catch class names that are too long to fit.
  local field_classes=$( git ls-files |
    grep -E '\.(cc|h)' | grep -v 'test\.cc$' |
    xargs grep -h -o -E '\b[^ ]+ : public Fields' | cut -f 1 -d ' ')
  local classname
  for classname in ${field_classes}; do
    if [ ! -e "$classname" ]; then
      continue
    fi
    if ! grep -E "\\b${classname}\\b" tools/fields_fuzzer.cc >/dev/null; then
      cat >&2 <<EOF
tools/fields_fuzzer.cc: Class ${classname} not found in the fields_fuzzer.
EOF
      ret=1
    fi
  done
  return $ret
}

# Test that we don't use %n in C++ code to avoid using it in printf and scanf.
# This test is not very precise but in cases where "module n" is needed we would
# normally have "% n" instead of "%n". Using %n is not allowed in Android 10+.
test_percent_n() {
  local ret=0
  local f
  for f in $(git ls-files | grep -E '(\.cc|\.cpp|\.h)$'); do
    if [ ! -e "$f" ]; then
      continue
    fi
    if grep -i -H -n -E '%h*n' "$f" >&2; then
      echo "Don't use \"%n\"." >&2
      ret=1
    fi
  done
  return ${ret}
}

main() {
  local ret=0
  cd "${MYDIR}"

  if ! git rev-parse >/dev/null 2>/dev/null; then
    echo "Not a git checkout, skipping bash_test"
    return 0
  fi

  IFS=$'\n'
  for f in $(declare -F); do
    local test_name=$(echo "$f" | cut -f 3 -d ' ')
    # Runs all the local bash functions that start with "test_".
    if [[ "${test_name}" == test_* ]]; then
      echo "Test ${test_name}: Start"
      if ${test_name}; then
        echo "Test ${test_name}: PASS"
      else
        echo "Test ${test_name}: FAIL"
        ret=1
      fi
    fi
  done
  return ${ret}
}

main "$@"
