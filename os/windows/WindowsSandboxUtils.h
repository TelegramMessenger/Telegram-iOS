
//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <audioclient.h>
#include <windows.h>
#include <mmdeviceapi.h>
#include <wrl.h>
#include <wrl/implements.h>

using namespace Microsoft::WRL;

namespace tgvoip{

class ActivationHandler : public IActivateAudioInterfaceCompletionHandler{
public:
	ActivationHandler(HANDLE _event);
	STDMETHOD(ActivateCompleted)(IActivateAudioInterfaceAsyncOperation* op);
	STDMETHOD(QueryInterface)(REFIID iid, void **pvObject);
	STDMETHOD_(ULONG, AddRef)();
	STDMETHOD_(ULONG, Release)();
	HANDLE event;
	IAudioClient* client;
	HRESULT actResult;
private:
	ULONG refCount;
};


class WindowsSandboxUtils{
public:
	static IAudioClient* ActivateAudioDevice(const wchar_t* devID, HRESULT* callResult, HRESULT* actResult);
};
}
