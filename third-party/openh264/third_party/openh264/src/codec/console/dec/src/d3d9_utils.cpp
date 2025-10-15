/*!
 * \copy
 *     Copyright (c)  2013, Cisco Systems
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
 */

#include "d3d9_utils.h"

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void Write2File (FILE* pFp, unsigned char* pData[3], int iStride[2], int iWidth, int iHeight);
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef ENABLE_DISPLAY_MODULE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define IDM_ABOUT                       104
#define IDM_EXIT                        105
#define IDI_TESTSHARESURFACE            107
#define IDI_SMALL                       108
#define IDC_TESTSHARESURFACE            109

#define NV12_FORMAT  MAKEFOURCC('N','V','1','2')

typedef struct {
  UINT      uiWidth;
  UINT      uiHeight;
  D3DFORMAT D3Dformat;
  D3DPOOL   D3DPool;
} SHandleInfo;

#define SAFE_RELEASE(p) if(p) { (p)->Release(); (p) = NULL; }
#define SAFE_FREE(p)    if(p) { free (p); (p) = NULL; }

HRESULT Dump2Surface (void* pDst[3], void* pSurface, int iWidth, int iHeight, int iStride[2]);
HRESULT InitWindow (HWND* hWnd);
LRESULT CALLBACK WndProc (HWND, UINT, WPARAM, LPARAM);

typedef HRESULT (WINAPI* pFnCreateD3D9Ex) (UINT SDKVersion, IDirect3D9Ex**);
typedef LPDIRECT3D9 (WINAPI* pFnCreateD3D9) (UINT SDKVersion);
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

CD3D9Utils::CD3D9Utils() {
  m_hDll        = NULL;
  m_hWnd        = NULL;
  m_pDumpYUV    = NULL;

  m_bInitDone   = FALSE;

  m_lpD3D9                = NULL;
  m_lpD3D9Device          = NULL;
  m_lpD3D9RawSurfaceShare = NULL;
  m_nWidth  = 0;
  m_nHeight = 0;
  // coverity scan uninitial
  ZeroMemory (&m_d3dpp, sizeof (m_d3dpp));
}

CD3D9Utils::~CD3D9Utils() {
  Uninit();
}

HRESULT CD3D9Utils::Init (BOOL bWindowed) {
  if (m_bInitDone)
    return S_OK;

  m_hDll = LoadLibrary (TEXT ("d3d9.dll"));
  pFnCreateD3D9 pCreateD3D9 = NULL;
  if (m_hDll)
    pCreateD3D9 = (pFnCreateD3D9) GetProcAddress (m_hDll, TEXT ("Direct3DCreate9"));
  else
    return E_FAIL;

  m_lpD3D9 = pCreateD3D9 (D3D_SDK_VERSION);

  return bWindowed ? InitWindow (&m_hWnd) : S_OK;
}

HRESULT CD3D9Utils::Uninit() {
  SAFE_RELEASE (m_lpD3D9RawSurfaceShare);
  SAFE_RELEASE (m_lpD3D9Device);
  SAFE_RELEASE (m_lpD3D9);
  SAFE_FREE (m_pDumpYUV);

  if (m_hDll) {
    FreeLibrary (m_hDll);
    m_hDll = NULL;
  }

  return S_OK;
}

HRESULT CD3D9Utils::Process (void* pDst[3], SBufferInfo* pInfo, FILE* pFp) {
  HRESULT hResult = E_FAIL;

  if (pDst == NULL || pInfo == NULL)
    return hResult;

  BOOL bWindowed = pFp ? FALSE : TRUE;
  BOOL bNeedD3D9 = ! (!bWindowed);
  if (!m_bInitDone)
    m_bInitDone = !bNeedD3D9;

  if (!m_bInitDone) {
    hResult = Init (bWindowed);
    if (SUCCEEDED (hResult))
      m_bInitDone = TRUE;
  }

  if (m_bInitDone) {
    if (bWindowed) {
      hResult = Render (pDst, pInfo);
      Sleep (30);
    } else if (pFp) {
      hResult = Dump (pDst, pInfo, pFp);
      Sleep (0);
    }
  }

  return hResult;
}

HRESULT CD3D9Utils::Render (void* pDst[3], SBufferInfo* pInfo) {
  HRESULT hResult = E_FAIL;

  if (!pInfo)
    return E_FAIL;

  if (m_nWidth != pInfo->UsrData.sSystemBuffer.iWidth
      || m_nHeight != pInfo->UsrData.sSystemBuffer.iHeight) {
    m_nWidth = pInfo->UsrData.sSystemBuffer.iWidth;
    m_nHeight = pInfo->UsrData.sSystemBuffer.iHeight;
    SAFE_RELEASE (m_lpD3D9RawSurfaceShare);
    SAFE_RELEASE (m_lpD3D9Device);
  }
  hResult = InitResource (NULL, pInfo);
  if (SUCCEEDED (hResult))
    hResult = Dump2Surface (pDst, m_lpD3D9RawSurfaceShare, pInfo->UsrData.sSystemBuffer.iWidth,
                            pInfo->UsrData.sSystemBuffer.iHeight, pInfo->UsrData.sSystemBuffer.iStride);

  if (SUCCEEDED (hResult)) {
    IDirect3DSurface9* pBackBuffer = NULL;
    hResult = m_lpD3D9Device->GetBackBuffer (0, 0, D3DBACKBUFFER_TYPE_MONO, &pBackBuffer);
    hResult = m_lpD3D9Device->StretchRect (m_lpD3D9RawSurfaceShare, NULL, pBackBuffer, NULL, D3DTEXF_NONE);
    hResult = m_lpD3D9Device->Present (0, 0, NULL, NULL);
  }

  return hResult;
}

HRESULT CD3D9Utils::Dump (void* pDst[3], SBufferInfo* pInfo, FILE* pFp) {
  HRESULT hResult = E_FAIL;
  int iStride[2];
  int iWidth;
  int iHeight;

  iWidth = pInfo->UsrData.sSystemBuffer.iWidth;
  iHeight = pInfo->UsrData.sSystemBuffer.iHeight;
  iStride[0] = pInfo->UsrData.sSystemBuffer.iStride[0];
  iStride[1] = pInfo->UsrData.sSystemBuffer.iStride[1];

  if (pDst[0] && pDst[1] && pDst[2])
    Write2File (pFp, (unsigned char**)pDst, iStride, iWidth, iHeight);

  return hResult;
}

HRESULT CD3D9Utils::InitResource (void* pSharedHandle, SBufferInfo* pInfo) {
  HRESULT hResult = S_OK;

  // coverity scan uninitial
  int iWidth = 0;
  int iHeight = 0;
  D3DFORMAT D3Dformat = (D3DFORMAT)D3DFMT_UNKNOWN;
  D3DPOOL D3Dpool = (D3DPOOL)D3DPOOL_DEFAULT;

  if (pInfo == NULL)
    return E_FAIL;

  if (m_lpD3D9Device == NULL && m_lpD3D9RawSurfaceShare == NULL) {
    HMONITOR hMonitorWnd = MonitorFromWindow (m_hWnd, MONITOR_DEFAULTTONULL);

    UINT uiAdapter = D3DADAPTER_DEFAULT;
    UINT uiCnt = m_lpD3D9->GetAdapterCount();
    for (UINT i = 0; i < uiCnt; i++) {
      HMONITOR hMonitor = m_lpD3D9->GetAdapterMonitor (i);
      if (hMonitor == hMonitorWnd) {
        uiAdapter = i;
        break;
      }
    }

    D3DDISPLAYMODE D3DDisplayMode;
    hResult = m_lpD3D9->GetAdapterDisplayMode (uiAdapter, &D3DDisplayMode);

    D3DDEVTYPE D3DDevType = D3DDEVTYPE_HAL;
    DWORD dwBehaviorFlags = D3DCREATE_SOFTWARE_VERTEXPROCESSING | D3DCREATE_MULTITHREADED;

    ZeroMemory (&m_d3dpp, sizeof (m_d3dpp));
    m_d3dpp.Flags = D3DPRESENTFLAG_VIDEO;
    m_d3dpp.SwapEffect = D3DSWAPEFFECT_DISCARD;
    m_d3dpp.BackBufferFormat = D3DDisplayMode.Format;
    m_d3dpp.Windowed = TRUE;
    m_d3dpp.hDeviceWindow = m_hWnd;
    m_d3dpp.PresentationInterval = D3DPRESENT_INTERVAL_IMMEDIATE;
    hResult = m_lpD3D9->CreateDevice (uiAdapter, D3DDevType, NULL, dwBehaviorFlags, &m_d3dpp, &m_lpD3D9Device);
    iWidth = pInfo->UsrData.sSystemBuffer.iWidth;
    iHeight = pInfo->UsrData.sSystemBuffer.iHeight;
    D3Dformat = (D3DFORMAT)NV12_FORMAT;
    D3Dpool = (D3DPOOL)D3DPOOL_DEFAULT;

    hResult = m_lpD3D9Device->CreateOffscreenPlainSurface (iWidth, iHeight, (D3DFORMAT)D3Dformat, (D3DPOOL)D3Dpool,
              &m_lpD3D9RawSurfaceShare, NULL);

  }

  if (m_lpD3D9Device == NULL || m_lpD3D9RawSurfaceShare == NULL)
    hResult = E_FAIL;

  return hResult;
}

CD3D9ExUtils::CD3D9ExUtils() {
  m_hDll        = NULL;
  m_hWnd        = NULL;
  m_pDumpYUV    = NULL;

  m_bInitDone   = FALSE;

  m_lpD3D9                = NULL;
  m_lpD3D9Device          = NULL;
  m_lpD3D9RawSurfaceShare = NULL;

  m_nWidth = 0;
  m_nHeight = 0;
  // coverity scan uninitial
  ZeroMemory (&m_d3dpp, sizeof (m_d3dpp));
}

CD3D9ExUtils::~CD3D9ExUtils() {
  Uninit();
}

HRESULT CD3D9ExUtils::Init (BOOL bWindowed) {
  if (m_bInitDone)
    return S_OK;

  m_hDll = LoadLibrary (TEXT ("d3d9.dll"));
  pFnCreateD3D9Ex pCreateD3D9Ex = NULL;
  if (m_hDll)
    pCreateD3D9Ex = (pFnCreateD3D9Ex) GetProcAddress (m_hDll, TEXT ("Direct3DCreate9Ex"));
  else
    return E_FAIL;

  pCreateD3D9Ex (D3D_SDK_VERSION, &m_lpD3D9);

  return bWindowed ? InitWindow (&m_hWnd) : S_OK;
}

HRESULT CD3D9ExUtils::Uninit() {
  SAFE_RELEASE (m_lpD3D9RawSurfaceShare);
  SAFE_RELEASE (m_lpD3D9Device);
  SAFE_RELEASE (m_lpD3D9);
  SAFE_FREE (m_pDumpYUV);

  if (m_hDll) {
    FreeLibrary (m_hDll);
    m_hDll = NULL;
  }

  return S_OK;
}

HRESULT CD3D9ExUtils::Process (void* pDst[3], SBufferInfo* pInfo, FILE* pFp) {
  HRESULT hResult = E_FAIL;

  if (pDst == NULL || pInfo == NULL)
    return hResult;

  BOOL bWindowed = pFp ? FALSE : TRUE;
  BOOL bNeedD3D9 = ! (!bWindowed);
  if (!m_bInitDone)
    m_bInitDone = !bNeedD3D9;

  if (!m_bInitDone) {
    hResult = Init (bWindowed);
    if (SUCCEEDED (hResult))
      m_bInitDone = TRUE;
  }

  if (m_bInitDone) {
    if (bWindowed) {
      hResult = Render (pDst, pInfo);
      Sleep (30); // set a simple time controlling with default of 30fps
    } else if (pFp) {
      hResult = Dump (pDst, pInfo, pFp);
      Sleep (0);
    }
  }

  return hResult;
}

HRESULT CD3D9ExUtils::Render (void* pDst[3], SBufferInfo* pInfo) {
  HRESULT hResult = E_FAIL;

  if (!pInfo)
    return E_FAIL;

  if (m_nWidth != pInfo->UsrData.sSystemBuffer.iWidth
      || m_nHeight != pInfo->UsrData.sSystemBuffer.iHeight) {
    m_nWidth = pInfo->UsrData.sSystemBuffer.iWidth;
    m_nHeight = pInfo->UsrData.sSystemBuffer.iHeight;
    MoveWindow (m_hWnd, 0, 0, pInfo->UsrData.sSystemBuffer.iWidth, pInfo->UsrData.sSystemBuffer.iHeight, true);
    SAFE_RELEASE (m_lpD3D9RawSurfaceShare);
    SAFE_RELEASE (m_lpD3D9Device);
  }
  hResult = InitResource (NULL, pInfo);
  if (SUCCEEDED (hResult))
    hResult = Dump2Surface (pDst, m_lpD3D9RawSurfaceShare, pInfo->UsrData.sSystemBuffer.iWidth,
                            pInfo->UsrData.sSystemBuffer.iHeight, pInfo->UsrData.sSystemBuffer.iStride);

  if (SUCCEEDED (hResult)) {
    IDirect3DSurface9* pBackBuffer = NULL;
    hResult = m_lpD3D9Device->GetBackBuffer (0, 0, D3DBACKBUFFER_TYPE_MONO, &pBackBuffer);
    hResult = m_lpD3D9Device->StretchRect (m_lpD3D9RawSurfaceShare, NULL, pBackBuffer, NULL, D3DTEXF_NONE);
    hResult = m_lpD3D9Device->PresentEx (0, 0, NULL, NULL, 0);
  }

  return hResult;
}

HRESULT CD3D9ExUtils::Dump (void* pDst[3], SBufferInfo* pInfo, FILE* pFp) {
  HRESULT hResult = E_FAIL;
  int iStride[2];
  int iWidth;
  int iHeight;

  iWidth = pInfo->UsrData.sSystemBuffer.iWidth;
  iHeight = pInfo->UsrData.sSystemBuffer.iHeight;
  iStride[0] = pInfo->UsrData.sSystemBuffer.iStride[0];
  iStride[1] = pInfo->UsrData.sSystemBuffer.iStride[1];

  if (pDst[0] && pDst[1] && pDst[2])
    Write2File (pFp, (unsigned char**)pDst, iStride, iWidth, iHeight);

  return hResult;
}

HRESULT CD3D9ExUtils::InitResource (void* pSharedHandle, SBufferInfo* pInfo) {
  HRESULT hResult = S_OK;
  int iWidth;
  int iHeight;
  D3DFORMAT D3Dformat;
  D3DPOOL D3Dpool;

  if (pInfo == NULL)
    return E_FAIL;

  if (m_lpD3D9Device == NULL && m_lpD3D9RawSurfaceShare == NULL) {
    HMONITOR hMonitorWnd = MonitorFromWindow (m_hWnd, MONITOR_DEFAULTTONULL);

    UINT uiAdapter = D3DADAPTER_DEFAULT;
    UINT uiCnt = m_lpD3D9->GetAdapterCount();
    for (UINT i = 0; i < uiCnt; i++) {
      HMONITOR hMonitor = m_lpD3D9->GetAdapterMonitor (i);
      if (hMonitor == hMonitorWnd) {
        uiAdapter = i;
        break;
      }
    }

    D3DDISPLAYMODEEX D3DDisplayMode;
    D3DDisplayMode.Size = sizeof (D3DDISPLAYMODEEX);
    hResult = m_lpD3D9->GetAdapterDisplayModeEx (uiAdapter, &D3DDisplayMode, NULL);

    D3DDEVTYPE D3DDevType = D3DDEVTYPE_HAL;
    DWORD dwBehaviorFlags = D3DCREATE_SOFTWARE_VERTEXPROCESSING | D3DCREATE_MULTITHREADED;

    ZeroMemory (&m_d3dpp, sizeof (m_d3dpp));
    m_d3dpp.Flags = D3DPRESENTFLAG_VIDEO;
    m_d3dpp.SwapEffect = D3DSWAPEFFECT_DISCARD;
    m_d3dpp.BackBufferFormat = D3DDisplayMode.Format;
    m_d3dpp.Windowed = TRUE;
    m_d3dpp.hDeviceWindow = m_hWnd;
    m_d3dpp.PresentationInterval = D3DPRESENT_INTERVAL_IMMEDIATE;
    hResult = m_lpD3D9->CreateDeviceEx (uiAdapter, D3DDevType, NULL, dwBehaviorFlags, &m_d3dpp, NULL, &m_lpD3D9Device);
    if (FAILED (hResult)) {
      return hResult;
    }
    iWidth = pInfo->UsrData.sSystemBuffer.iWidth;
    iHeight = pInfo->UsrData.sSystemBuffer.iHeight;
    D3Dformat = (D3DFORMAT)NV12_FORMAT;
    D3Dpool = (D3DPOOL)D3DPOOL_DEFAULT;
    hResult = m_lpD3D9Device->CreateOffscreenPlainSurface (iWidth, iHeight, (D3DFORMAT)D3Dformat, (D3DPOOL)D3Dpool,
              &m_lpD3D9RawSurfaceShare, &pSharedHandle);
  }

  if (m_lpD3D9Device == NULL || m_lpD3D9RawSurfaceShare == NULL)
    hResult = E_FAIL;

  return hResult;
}


HRESULT Dump2Surface (void* pDst[3], void* pSurface, int iWidth, int iHeight, int iStride[2]) {
  HRESULT hResult = E_FAIL;

  if (!pDst[0] || !pDst[1] || !pDst[2] || !pSurface)
    return hResult;

  IDirect3DSurface9* pSurfaceData = (IDirect3DSurface9*)pSurface;
  D3DLOCKED_RECT sD3DLockedRect = {0};
  hResult = pSurfaceData->LockRect (&sD3DLockedRect, NULL, 0);

  unsigned char* pInY = (unsigned char*)pDst[0];
  unsigned char* pOutY = (unsigned char*)sD3DLockedRect.pBits;
  int iOutStride = sD3DLockedRect.Pitch;

  for (int j = 0; j < iHeight; j++)
    memcpy (pOutY + j * iOutStride, pInY + j * iStride[0], iWidth); //confirmed_safe_unsafe_usage

  unsigned char* pInU = (unsigned char*)pDst[1];
  unsigned char* pInV = (unsigned char*)pDst[2];
  unsigned char* pOutC = pOutY + iOutStride * iHeight;
  for (int i = 0; i < iHeight / 2; i++) {
    for (int j = 0; j < iWidth; j += 2) {
      pOutC[i * iOutStride + j  ] = pInU[i * iStride[1] + j / 2];
      pOutC[i * iOutStride + j + 1] = pInV[i * iStride[1] + j / 2];
    }
  }

  pSurfaceData->UnlockRect();

  return hResult;
}

HRESULT InitWindow (HWND* hWnd) {
  const TCHAR kszWindowTitle[] = TEXT ("Wels Decoder Application");
  const TCHAR kszWindowClass[] = TEXT ("Wels Decoder Class");

  WNDCLASSEX sWndClassEx = {0};
  sWndClassEx.cbSize            = sizeof (WNDCLASSEX);
  sWndClassEx.style             = CS_HREDRAW | CS_VREDRAW;
  sWndClassEx.lpfnWndProc       = (WNDPROC)WndProc;
  sWndClassEx.cbClsExtra        = 0;
  sWndClassEx.cbWndExtra        = 0;
  sWndClassEx.hInstance         = GetModuleHandle (NULL);
  sWndClassEx.hIcon             = LoadIcon (sWndClassEx.hInstance, (LPCTSTR)IDI_TESTSHARESURFACE);
  sWndClassEx.hCursor           = LoadCursor (NULL, IDC_ARROW);
  sWndClassEx.hbrBackground     = (HBRUSH) (COLOR_WINDOW + 1);
  sWndClassEx.lpszMenuName      = (LPCSTR)IDC_TESTSHARESURFACE;
  sWndClassEx.lpszClassName     = kszWindowClass;
  sWndClassEx.hIconSm           = LoadIcon (sWndClassEx.hInstance, (LPCTSTR)IDI_SMALL);

  if (!RegisterClassEx (&sWndClassEx))
    return E_FAIL;

  HWND hTmpWnd = CreateWindow (kszWindowClass, kszWindowTitle, WS_OVERLAPPEDWINDOW,
                               CW_USEDEFAULT, 0, CW_USEDEFAULT, 0, NULL, NULL, sWndClassEx.hInstance, NULL);

  *hWnd = hTmpWnd;
  if (!hTmpWnd)
    return E_FAIL;

  ShowWindow (hTmpWnd, SW_SHOWDEFAULT);
  UpdateWindow (hTmpWnd);

  return S_OK;
}

LRESULT CALLBACK WndProc (HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
  INT wmId, wmEvent;

  switch (message) {
  case WM_COMMAND:
    wmId    = LOWORD (wParam);
    wmEvent = HIWORD (wParam);
    switch (wmId) {
    case IDM_ABOUT:
      break;
    case IDM_EXIT:
      DestroyWindow (hWnd);
      break;
    default:
      return DefWindowProc (hWnd, message, wParam, lParam);
    }
    break;
  case WM_PAINT:
    ValidateRect (hWnd , NULL);
    break;
  case WM_DESTROY:
    PostQuitMessage (0);
    break;
  default:
    return DefWindowProc (hWnd, message, wParam, lParam);
  }
  return 0;
}

#endif

CUtils::CUtils() {
  hHandle = NULL;
  iOSType = CheckOS();

#ifdef ENABLE_DISPLAY_MODULE
  if (iOSType == OS_XP)
    hHandle = (void*) new CD3D9Utils;

  else if (iOSType == OS_VISTA_UPPER)
    hHandle = (void*) new CD3D9ExUtils;
#endif

  if (hHandle == NULL)
    iOSType = OS_UNSUPPORTED;
}

CUtils::~CUtils() {
#ifdef ENABLE_DISPLAY_MODULE
  if (hHandle) {
    if (iOSType == OS_XP) {
      CD3D9Utils* hTmp = (CD3D9Utils*) hHandle;
      delete hTmp;
    } else if (iOSType == OS_VISTA_UPPER) {
      CD3D9ExUtils* hTmp = (CD3D9ExUtils*) hHandle;
      delete hTmp;
    }
    hHandle = NULL;
  }
#endif
}

int CUtils::Process (void* pDst[3], SBufferInfo* pInfo, FILE* pFp) {

  int iRet = 0;

  if (iOSType == OS_UNSUPPORTED) {
    if (pFp && pDst[0] && pDst[1] && pDst[2] && pInfo) {
      int iStride[2];
      int iWidth = pInfo->UsrData.sSystemBuffer.iWidth;
      int iHeight = pInfo->UsrData.sSystemBuffer.iHeight;
      iStride[0] = pInfo->UsrData.sSystemBuffer.iStride[0];
      iStride[1] = pInfo->UsrData.sSystemBuffer.iStride[1];

      Write2File (pFp, (unsigned char**)pDst, iStride, iWidth, iHeight);
    }
  }

#ifdef ENABLE_DISPLAY_MODULE
  else {
    MSG msg;
    ZeroMemory (&msg, sizeof (msg));
    while (msg.message != WM_QUIT) {
      if (PeekMessage (&msg, NULL, 0U, 0U, PM_REMOVE)) {
        TranslateMessage (&msg);
        DispatchMessage (&msg);
      } else {
        HRESULT hResult = S_OK;
        if (iOSType == OS_XP)
          hResult = ((CD3D9Utils*)hHandle)->Process (pDst, pInfo, pFp);

        else if (iOSType == OS_VISTA_UPPER)
          hResult = ((CD3D9ExUtils*)hHandle)->Process (pDst, pInfo, pFp);

        iRet = !SUCCEEDED (hResult);
        break;
      }
    }
  }
#endif

  return iRet;
}

int CUtils::CheckOS() {
  int iType = OS_UNSUPPORTED;

#ifdef ENABLE_DISPLAY_MODULE
  OSVERSIONINFOEX osvi;
  ZeroMemory (&osvi, sizeof (OSVERSIONINFOEX));
  osvi.dwOSVersionInfoSize = sizeof (OSVERSIONINFOEX);
  osvi.dwPlatformId = VER_PLATFORM_WIN32_NT;
  osvi.dwMajorVersion = 6; // Vista
  DWORDLONG condmask = VerSetConditionMask (VerSetConditionMask (0, VER_MAJORVERSION, VER_GREATER_EQUAL),
                       VER_PLATFORMID, VER_EQUAL);

  if (VerifyVersionInfo (&osvi, VER_MAJORVERSION | VER_PLATFORMID, condmask)) {
    iType = OS_VISTA_UPPER;
  } else {
    osvi.dwMajorVersion = 5; // XP/2000
    if (VerifyVersionInfo (&osvi, VER_MAJORVERSION | VER_PLATFORMID, condmask))
      iType = OS_XP;
  }
#endif

  return iType;
}

void Write2File (FILE* pFp, unsigned char* pData[3], int iStride[2], int iWidth, int iHeight) {
  int   i;
  unsigned char*  pPtr = NULL;

  pPtr = pData[0];
  for (i = 0; i < iHeight; i++) {
    fwrite (pPtr, 1, iWidth, pFp);
    pPtr += iStride[0];
  }

  iHeight = iHeight / 2;
  iWidth = iWidth / 2;
  pPtr = pData[1];
  for (i = 0; i < iHeight; i++) {
    fwrite (pPtr, 1, iWidth, pFp);
    pPtr += iStride[1];
  }

  pPtr = pData[2];
  for (i = 0; i < iHeight; i++) {
    fwrite (pPtr, 1, iWidth, pFp);
    pPtr += iStride[1];
  }
}
