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

#define CHECK_AU_ERROR(res, msg) if(res!=noErr){ LOGE(msg": OSStatus=%d", (int)res); return; }
#define BUFFER_SIZE 960 // 20 ms

#define kOutputBus 0
#define kInputBus 1

int CAudioUnitIO::refCount=0;
CAudioUnitIO* CAudioUnitIO::sharedInstance=NULL;

CAudioUnitIO::CAudioUnitIO(){
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
	
	input=NULL;
	output=NULL;
	configured=false;
	inputEnabled=false;
	outputEnabled=false;
	inBufferList.mBuffers[0].mData=malloc(10240);
	inBufferList.mBuffers[0].mDataByteSize=10240;
	inBufferList.mNumberBuffers=1;
}

CAudioUnitIO::~CAudioUnitIO(){
	AudioOutputUnitStop(unit);
	AudioUnitUninitialize(unit);
	AudioComponentInstanceDispose(unit);
	free(inBufferList.mBuffers[0].mData);
}

CAudioUnitIO* CAudioUnitIO::Get(){
	if(refCount==0){
		sharedInstance=new CAudioUnitIO();
	}
	refCount++;
	assert(refCount>0);
	return sharedInstance;
}

void CAudioUnitIO::Release(){
	refCount--;
	assert(refCount>=0);
	if(refCount==0){
		delete sharedInstance;
		sharedInstance=NULL;
	}
}

void CAudioUnitIO::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	if(configured)
		return;
	UInt32 flag=1;
	OSStatus status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error enabling AudioUnit output");
	status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error enabling AudioUnit input");
	
	flag=1;
	status=AudioUnitSetProperty(unit, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAudioUnitScope_Global, kInputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error disabling AGC");
	
	/*AudioStreamBasicDescription nativeInFormat, nativeOutFormat;
	UInt32 size=sizeof(AudioStreamBasicDescription);
	AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBus, &nativeInFormat, &size);
	size=sizeof(AudioStreamBasicDescription);
	AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &nativeOutFormat, &size);
	LOGI("native in format: %d hz, flags %08X, %d channels, %d bits", (int)nativeInFormat.mSampleRate, nativeInFormat.mFormatFlags, nativeInFormat.mChannelsPerFrame, nativeInFormat.mBitsPerChannel);
	LOGI("native out format: %d hz, flags %08X, %d channels, %d bits", (int)nativeOutFormat.mSampleRate, nativeOutFormat.mFormatFlags, nativeOutFormat.mChannelsPerFrame, nativeOutFormat.mBitsPerChannel);*/
	Float64 nativeSampleRate;
	UInt32 size=sizeof(Float64);
	status=AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &nativeSampleRate);
	
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
	
	callbackStruct.inputProc = CAudioUnitIO::BufferCallback;
	callbackStruct.inputProcRefCon = this;
	status = AudioUnitSetProperty(unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, kOutputBus, &callbackStruct, sizeof(callbackStruct));
	CHECK_AU_ERROR(status, "Error setting output buffer callback");
	status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, kInputBus, &callbackStruct, sizeof(callbackStruct));
	CHECK_AU_ERROR(status, "Error setting input buffer callback");
	
	status = AudioUnitInitialize(unit);
	CHECK_AU_ERROR(status, "Error initializing AudioUnit");
	status=AudioOutputUnitStart(unit);
	CHECK_AU_ERROR(status, "Error starting AudioUnit");
	
	configured=true;
}

OSStatus CAudioUnitIO::BufferCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
	((CAudioUnitIO*)inRefCon)->BufferCallback(ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
	return noErr;
}

void CAudioUnitIO::BufferCallback(AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 bus, UInt32 numFrames, AudioBufferList *ioData){
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

void CAudioUnitIO::AttachInput(CAudioInputAudioUnit *i){
	assert(input==NULL);
	input=i;
}

void CAudioUnitIO::AttachOutput(CAudioOutputAudioUnit *o){
	assert(output==NULL);
	output=o;
}

void CAudioUnitIO::DetachInput(){
	assert(input!=NULL);
	input=NULL;
	inputEnabled=false;
}

void CAudioUnitIO::DetachOutput(){
	assert(output!=NULL);
	output=NULL;
	outputEnabled=false;
}

void CAudioUnitIO::EnableInput(bool enabled){
	inputEnabled=enabled;
}

void CAudioUnitIO::EnableOutput(bool enabled){
	outputEnabled=enabled;
}

