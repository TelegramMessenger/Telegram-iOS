//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//
#include <stdio.h>
#include <AudioToolbox/AudioToolbox.h>
#include "AudioUnitIO.h"
#include "AudioInputAudioUnit.h"
#include "AudioOutputAudioUnit.h"
#include "../../logging.h"
#include "../../VoIPController.h"
#include "../../VoIPServerConfig.h"

#define CHECK_AU_ERROR(res, msg) if(res!=noErr){ LOGE(msg": OSStatus=%d", (int)res); return; }
#define BUFFER_SIZE 960 // 20 ms

#define kOutputBus 0
#define kInputBus 1

using namespace tgvoip;
using namespace tgvoip::audio;

int AudioUnitIO::refCount=0;
AudioUnitIO* AudioUnitIO::sharedInstance=NULL;
bool AudioUnitIO::haveAudioSession=false;

AudioUnitIO::AudioUnitIO(){
	input=NULL;
	output=NULL;
	configured=false;
	inputEnabled=false;
	outputEnabled=false;
	inBufferList.mBuffers[0].mData=malloc(10240);
	inBufferList.mBuffers[0].mDataByteSize=10240;
	inBufferList.mNumberBuffers=1;
#ifdef TGVOIP_USE_AUDIO_SESSION
	if(haveAudioSession)
		ProcessAudioSessionAcquired();
#else
	haveAudioSession=true;
	ProcessAudioSessionAcquired();
#endif
}

AudioUnitIO::~AudioUnitIO(){
	if(runFakeIO){
		runFakeIO=false;
		join_thread(fakeIOThread);
	}
	AudioOutputUnitStop(unit);
	AudioUnitUninitialize(unit);
	AudioComponentInstanceDispose(unit);
	free(inBufferList.mBuffers[0].mData);
	haveAudioSession=false;
}

void AudioUnitIO::ProcessAudioSessionAcquired(){
	OSStatus status;
	AudioComponentDescription desc;
	AudioComponent inputComponent;
	desc.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE
	//desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
#else
	desc.componentSubType = kAudioUnitSubType_HALOutput;
#endif
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	inputComponent = AudioComponentFindNext(NULL, &desc);
	status = AudioComponentInstanceNew(inputComponent, &unit);
	
	if(configured)
		ActuallyConfigure(cfgSampleRate, cfgBitsPerSample, cfgChannels);
}

AudioUnitIO* AudioUnitIO::Get(){
	if(refCount==0){
		sharedInstance=new AudioUnitIO();
	}
	refCount++;
	assert(refCount>0);
	return sharedInstance;
}

void AudioUnitIO::Release(){
	refCount--;
	assert(refCount>=0);
	if(refCount==0){
		delete sharedInstance;
		sharedInstance=NULL;
	}
}

void AudioUnitIO::AudioSessionAcquired(){
	haveAudioSession=true;
	if(sharedInstance)
		sharedInstance->ProcessAudioSessionAcquired();
}

void AudioUnitIO::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	if(configured)
		return;
	
#ifdef TGVOIP_USE_AUDIO_SESSION
	runFakeIO=true;
	start_thread(fakeIOThread, AudioUnitIO::StartFakeIOThread, this);
	set_thread_priority(fakeIOThread, get_thread_max_priority());
#endif
	
	if(haveAudioSession){
		ActuallyConfigure(sampleRate, bitsPerSample, channels);
	}else{
		cfgSampleRate=sampleRate;
		cfgBitsPerSample=bitsPerSample;
		cfgChannels=channels;
	}
	
	configured=true;
}

void AudioUnitIO::ActuallyConfigure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	UInt32 flag=1;
	OSStatus status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error enabling AudioUnit output");
	status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error enabling AudioUnit input");
	
	flag=ServerConfig::GetSharedInstance()->GetBoolean("use_ios_vpio_agc", true) ? 1 : 0;
	status=AudioUnitSetProperty(unit, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAudioUnitScope_Global, kInputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error disabling AGC");
	
	AudioStreamBasicDescription audioFormat;
	audioFormat.mSampleRate			= sampleRate;
	audioFormat.mFormatID			= kAudioFormatLinearPCM;
	audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
	audioFormat.mFramesPerPacket	= 1;
	audioFormat.mChannelsPerFrame	= channels;
	audioFormat.mBitsPerChannel		= bitsPerSample*channels;
	audioFormat.mBytesPerPacket		= bitsPerSample/8*channels;
	audioFormat.mBytesPerFrame		= bitsPerSample/8*channels;
	
	status = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &audioFormat, sizeof(audioFormat));
	CHECK_AU_ERROR(status, "Error setting output format");
	status = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBus, &audioFormat, sizeof(audioFormat));
	CHECK_AU_ERROR(status, "Error setting input format");
	
	AURenderCallbackStruct callbackStruct;
	
	callbackStruct.inputProc = AudioUnitIO::BufferCallback;
	callbackStruct.inputProcRefCon = this;
	status = AudioUnitSetProperty(unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, kOutputBus, &callbackStruct, sizeof(callbackStruct));
	CHECK_AU_ERROR(status, "Error setting output buffer callback");
	status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, kInputBus, &callbackStruct, sizeof(callbackStruct));
	CHECK_AU_ERROR(status, "Error setting input buffer callback");
	
	status = AudioUnitInitialize(unit);
	CHECK_AU_ERROR(status, "Error initializing AudioUnit");
	status=AudioOutputUnitStart(unit);
	CHECK_AU_ERROR(status, "Error starting AudioUnit");
}

OSStatus AudioUnitIO::BufferCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
	((AudioUnitIO*)inRefCon)->BufferCallback(ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
	return noErr;
}

void AudioUnitIO::BufferCallback(AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 bus, UInt32 numFrames, AudioBufferList *ioData){
	runFakeIO=false;
	if(bus==kOutputBus){
		if(output && outputEnabled){
			output->HandleBufferCallback(ioData);
		}else{
			memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
		}
	}else if(bus==kInputBus){
		if(input && inputEnabled){
			inBufferList.mBuffers[0].mDataByteSize=10240;
			AudioUnitRender(unit, ioActionFlags, inTimeStamp, bus, numFrames, &inBufferList);
			input->HandleBufferCallback(&inBufferList);
		}
	}
}

void AudioUnitIO::AttachInput(AudioInputAudioUnit *i){
	assert(input==NULL);
	input=i;
}

void AudioUnitIO::AttachOutput(AudioOutputAudioUnit *o){
	assert(output==NULL);
	output=o;
}

void AudioUnitIO::DetachInput(){
	assert(input!=NULL);
	input=NULL;
	inputEnabled=false;
}

void AudioUnitIO::DetachOutput(){
	assert(output!=NULL);
	output=NULL;
	outputEnabled=false;
}

void AudioUnitIO::EnableInput(bool enabled){
	inputEnabled=enabled;
}

void AudioUnitIO::EnableOutput(bool enabled){
	outputEnabled=enabled;
}

void* AudioUnitIO::StartFakeIOThread(void *arg){
	((AudioUnitIO*)arg)->RunFakeIOThread();
	return NULL;
}

void AudioUnitIO::RunFakeIOThread(){
	double neededDataDuration=0;
	double prevTime=VoIPController::GetCurrentTime();
	while(runFakeIO){
		double t=VoIPController::GetCurrentTime();
		neededDataDuration+=t-prevTime;
		prevTime=t;
		while(neededDataDuration>=0.020){
			if(output && outputEnabled){
				inBufferList.mBuffers[0].mDataByteSize=960*2;
				output->HandleBufferCallback(&inBufferList);
			}
			if((output && outputEnabled) || (input && inputEnabled)){
				memset(inBufferList.mBuffers[0].mData, 0, 960*2);
			}
			if(input && inputEnabled){
				inBufferList.mBuffers[0].mDataByteSize=960*2;
				input->HandleBufferCallback(&inBufferList);
			}
			neededDataDuration-=0.020;
		}
		usleep(5000);
	}
	LOGD("FakeIO thread exiting");
}

