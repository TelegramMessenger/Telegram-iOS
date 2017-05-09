
//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <audioclient.h>
#include <wrl/implements.h>

namespace tgvoip{

using namespace Microsoft::WRL;

class ActivationHandler : public RuntimeClass< RuntimeClassFlags< ClassicCom >, FtmBase, IActivateAudioInterfaceCompletionHandler >{
public:
	ActivationHandler(HANDLE _event);
	STDMETHOD(ActivateCompleted)(IActivateAudioInterfaceAsyncOperation* op);
	HANDLE event;
	IAudioClient* client;
	HRESULT actResult;
};


class WindowsSandboxUtils{
public:
	static IAudioClient* ActivateAudioDevice(const wchar_t* devID, HRESULT* callResult, HRESULT* actResult);
};
}
