#!/usr/bin/env bash
cd $(dirname $0)

COMMIT_FILES="example/cpp/CMakeLists.txt example/uwp/extension.vsixmanifest example/uwp/Telegram.Td.UWP.nuspec example/web/tdweb/package.json example/web/tdweb/package-lock.json README.md td/telegram/OptionManager.cpp"

# check argument '-i' to drop all fixed files list.
for arg in "$@"; do if [[ "$arg" == "-i" ]]; then COMMIT_FILES=""; break; fi; done

# 'git diff' to ensure that 'CMakeLists.txt' is modified.
GIT_DIFF=$(git --no-pager diff --unified=0 CMakeLists.txt)

SED_REGEX="project\(TDLib VERSION ([0-9\.]+) LANGUAGES CXX C\)"

OLD_TDLIB_VERSION=$(echo "${GIT_DIFF}" | sed -nr "s/\-$SED_REGEX/\1/p")
NEW_TDLIB_VERSION=$(echo "${GIT_DIFF}" | sed -nr "s/\+$SED_REGEX/\1/p")

if [ ! -z "${OLD_TDLIB_VERSION}" ] && [ ! -z "${NEW_TDLIB_VERSION}" ] &&
  [ "${OLD_TDLIB_VERSION}" != "${NEW_TDLIB_VERSION}" ] ; then

  for arg in "$@" ; do
    if [[ "$arg" == "-i" ]] ; then
      continue
    elif [ -e "$arg" ] ; then
      if [[ "$COMMIT_FILES" == "" ]] ; then
        COMMIT_FILES="$arg"
      else
        COMMIT_FILES="$COMMIT_FILES $arg"
      fi
    else
      echo "$arg: No such file or directory"; exit 1
    fi
  done

  if [[ "$COMMIT_FILES" == "" ]] ; then
    echo "No files to update."; exit 1
  fi

  # Replace all matches
  sed --binary -i "s/${OLD_TDLIB_VERSION//./\\.}/${NEW_TDLIB_VERSION}/g" $COMMIT_FILES || exit 1

  git --no-pager diff CMakeLists.txt $COMMIT_FILES

  echo -e "\n\n"
  read -p "Commit \"Update version to ${NEW_TDLIB_VERSION}.\" (y/n)? " answer

  if [[ "${answer}" == "Y" ]] || [[ "${answer}" == "y" ]] ; then
    git commit --quiet -n CMakeLists.txt $COMMIT_FILES -m "Update version to ${NEW_TDLIB_VERSION}."; echo
    git --no-pager log --stat -n 1
  else
    # Undo sed changes
    sed --binary -i "s/${NEW_TDLIB_VERSION//./\\.}/${OLD_TDLIB_VERSION}/g" $COMMIT_FILES || exit 1
    echo "Aborted."; exit 1
  fi
else
  echo "Couldn't find new TDLib version."
fi
