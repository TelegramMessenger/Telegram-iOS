/*!
 * \copy
 *     Copyright (c)  2008-2013, Cisco Systems
 *     All rights reserved.
 *
 *     Redistribution and use in source and binary forms, with or without
 *     modification, are permitted provided that the following conditions
 *     are met:
 *
 *        * Redistributions of source code must retain the above copyright
 *          notice, this list of conditions and the following disclaimer.
 *
 *        * Redistributions in binary form must reproduce the above copyright
 *          notice, this list of conditions and the following disclaimer in
 *          the documentation and/or other materials provided with the
 *          distribution.
 *
 *     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 *     FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *     COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 *     INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *     BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 *     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 *     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *     ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *     POSSIBILITY OF SUCH DAMAGE.
 *
 *  read_config.h
 *
 *  Abstract
 *      Class for reading parameter settings in a configure file.
 *
 *  History
 *      08/18/2008 Created
 *
 *****************************************************************************/

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <string.h>
#include "read_config.h"

CReadConfig::CReadConfig()
  : m_pCfgFile (NULL)
  , m_strCfgFileName ("")
  , m_iLines (0) {
}

CReadConfig::CReadConfig (const char* kpConfigFileName)
  : m_pCfgFile (0)
  , m_strCfgFileName (kpConfigFileName)
  , m_iLines (0) {
  if (strlen (kpConfigFileName) > 0) { // confirmed_safe_unsafe_usage
    m_pCfgFile = fopen (kpConfigFileName, "r");
  }
}

CReadConfig::CReadConfig (const std::string& kpConfigFileName)
  : m_pCfgFile (0)
  , m_strCfgFileName (kpConfigFileName)
  , m_iLines (0) {
  if (kpConfigFileName.length() > 0) {
    m_pCfgFile = fopen (kpConfigFileName.c_str(), "r");
  }
}

CReadConfig::~CReadConfig() {
  if (m_pCfgFile) {
    fclose (m_pCfgFile);
    m_pCfgFile = NULL;
  }
}

void CReadConfig::Openf (const char* kpStrFile) {
  if (kpStrFile != NULL && strlen (kpStrFile) > 0) { // confirmed_safe_unsafe_usage
    m_strCfgFileName = kpStrFile;
    m_pCfgFile = fopen (kpStrFile, "r");
  }
}

long CReadConfig::ReadLine (std::string* pVal, const int kiValSize/* = 4*/) {
  if (m_pCfgFile == NULL || pVal == NULL || kiValSize <= 1)
    return 0;

  std::string* strTags = &pVal[0];
  int nTagNum = 0, n = 0;
  bool bCommentFlag = false;

  while (n < kiValSize) {
    pVal[n] = "";
    ++ n;
  }

  do {
    const char kCh = (char)fgetc (m_pCfgFile);

    if (kCh == '\n' || feof (m_pCfgFile)) {
      ++ m_iLines;
      break;
    }
    if (kCh == '#')
      bCommentFlag = true;
    if (!bCommentFlag) {
      if (kCh == '\t' || kCh == ' ') {
        if (nTagNum >= kiValSize - 1)
          break;
        if (! (*strTags).empty()) {
          ++ nTagNum;
          strTags = &pVal[nTagNum];
        }
      } else
        *strTags += kCh;
    }

  } while (true);

  return 1 + nTagNum;
}

const bool CReadConfig::EndOfFile() {
  if (m_pCfgFile == NULL)
    return true;
  return feof (m_pCfgFile) ? true : false;
}

const int CReadConfig::GetLines() {
  return m_iLines;
}

const bool CReadConfig::ExistFile() {
  return (m_pCfgFile != NULL);
}

const std::string& CReadConfig::GetFileName() {
  return m_strCfgFileName;
}
