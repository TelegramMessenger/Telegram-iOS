
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

namespace tgvoip {

	class ActivationHandler :
		public RuntimeClass< RuntimeClassFlags< ClassicCom >, FtmBase, IActivateAudioInterfaceCompletionHandler >
	{
	public:
		STDMETHOD(ActivateCompleted)(IActivateAudioInterfaceAsyncOperation *operation);

		ActivationHandler(HANDLE _event);
		HANDLE event;
		IAudioClient2* client;
		HRESULT actResult;
	};

	class WindowsSandboxUtils {
	public:
		static IAudioClient2* ActivateAudioDevice(const wchar_t* devID, HRESULT* callResult, HRESULT* actResult);
	};
}
