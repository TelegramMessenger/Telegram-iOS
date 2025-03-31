#!/usr/bin/env bash

# The script checks that all needed tools are installed and sets OS_NAME, HOST_ARCH, and WGET variables

if [[ "$OSTYPE" == "linux"* ]] ; then
  OS_NAME="linux"
  HOST_ARCH="linux-x86_64"
elif [[ "$OSTYPE" == "darwin"* ]] ; then
  OS_NAME="mac"
  HOST_ARCH="darwin-x86_64"
elif [[ "$OSTYPE" == "msys" ]] ; then
  OS_NAME="win"
  HOST_ARCH="windows-x86_64"
else
  echo "Error: this script supports only Bash shell on Linux, macOS, or Windows."
  exit 1
fi

if which wget >/dev/null 2>&1 ; then
  WGET="wget -q"
elif which curl >/dev/null 2>&1 ; then
  WGET="curl -sfLO"
else
  echo "Error: this script requires either curl or wget tool installed."
  exit 1
fi

for TOOL_NAME in gperf jar java javadoc make perl php sed tar yes unzip ; do
  if ! which "$TOOL_NAME" >/dev/null 2>&1 ; then
    echo "Error: this script requires $TOOL_NAME tool installed."
    exit 1
  fi
done

if [[ $(which make) = *" "* ]] ; then
  echo "Error: OpenSSL expects that full path to make tool doesn't contain spaces. Move it to some other place."
  exit 1
fi

if ! perl -MExtUtils::MakeMaker -MLocale::Maketext::Simple -MPod::Usage -e '' >/dev/null 2>&1 ; then
  echo "Error: Perl installation is broken."
  if [[ "$OSTYPE" == "msys" ]] ; then
    echo "For Git Bash you need to manually copy ExtUtils, Locale and Pod modules to /usr/share/perl5/core_perl from any compatible Perl installation."
  fi
  exit 1
fi

if ! java --help >/dev/null 2>&1 ; then
  echo "Error: Java installation is broken. Install JDK from https://www.oracle.com/java/technologies/downloads/ or via the package manager."
  exit 1
fi
