//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//


#ifndef LIBTGVOIP_AUDIOIO_H
#define LIBTGVOIP_AUDIOIO_H

#include "AudioInput.h"
#include "AudioOutput.h"
#include <memory>
#include <string>

namespace tgvoip{
	namespace audio {
		class AudioIO{
		public:
			virtual ~AudioIO(){};
			static std::shared_ptr<AudioIO> Create();
			virtual AudioInput* GetInput()=0;
			virtual AudioOutput* GetOutput()=0;
			bool Failed();
			std::string GetErrorDescription();
		protected:
			bool failed=false;
			std::string error;
		};
		
		template<class I, class O> class ContextlessAudioIO : public AudioIO{
		public:
			ContextlessAudioIO(){
				input=new I();
				output=new O();
			}

			ContextlessAudioIO(std::string inputDeviceID, std::string outputDeviceID){
				input=new I(inputDeviceID);
				output=new O(outputDeviceID);
			}
			
			virtual ~ContextlessAudioIO(){
				delete input;
				delete output;
			}
			
			virtual AudioInput* GetInput(){
				return input;
			}
			
			virtual AudioOutput* GetOutput(){
				return output;
			}
		private:
			I* input;
			O* output;
		};
	}
}

#endif //LIBTGVOIP_AUDIOIO_H
