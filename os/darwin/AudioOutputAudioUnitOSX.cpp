//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <stdlib.h>
#include <stdio.h>
#include "AudioOutputAudioUnitOSX.h"
#include "../../logging.h"

#define BUFFER_SIZE 960
#define CHECK_AU_ERROR(res, msg) if(res!=noErr){ LOGE("output: " msg": OSStatus=%d", (int)res); return; }

#define kOutputBus 0
#define kInputBus 1


CAudioOutputAudioUnit::CAudioOutputAudioUnit(){
	remainingDataSize=0;
	isPlaying=false;
	
	OSStatus status;
	AudioComponentDescription inputDesc={
		.componentType = kAudioUnitType_Output, .componentSubType = kAudioUnitSubType_HALOutput, .componentFlags = 0, .componentFlagsMask = 0,
		.componentManufacturer = kAudioUnitManufacturer_Apple
	};
	AudioComponent component=AudioComponentFindNext(NULL, &inputDesc);
	status=AudioComponentInstanceNew(component, &unit);
	CHECK_AU_ERROR(status, "Error creating AudioUnit");
	
	UInt32 flag=1;
	status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error enabling AudioUnit output");
	flag=0;
	status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error enabling AudioUnit input");
	
	UInt32 size=sizeof(AudioDeviceID);
	AudioDeviceID outputDevice;
	AudioObjectPropertyAddress propertyAddress;
	propertyAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
	propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
	propertyAddress.mElement = kAudioObjectPropertyElementMaster;
	
	UInt32 propsize = sizeof(AudioDeviceID);
	status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &propsize, &outputDevice);
	CHECK_AU_ERROR(status, "Error getting default output device");
 
	status =AudioUnitSetProperty(unit,
							  kAudioOutputUnitProperty_CurrentDevice,
							  kAudioUnitScope_Global,
							  kOutputBus,
							  &outputDevice,
							  size);
	CHECK_AU_ERROR(status, "Error setting input device");
	
	AudioStreamBasicDescription hardwareFormat;
	size=sizeof(hardwareFormat);
	status=AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kOutputBus, &hardwareFormat, &size);
	CHECK_AU_ERROR(status, "Error getting hardware format");
	
	AudioStreamBasicDescription desiredFormat={
		.mSampleRate=/*hardwareFormat.mSampleRate*/48000, .mFormatID=kAudioFormatLinearPCM, .mFormatFlags=kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
		.mFramesPerPacket=1, .mChannelsPerFrame=1, .mBitsPerChannel=16, .mBytesPerPacket=2, .mBytesPerFrame=2
	};
	
	status=AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &desiredFormat, sizeof(desiredFormat));
	CHECK_AU_ERROR(status, "Error setting format");
	
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc = CAudioOutputAudioUnit::BufferCallback;
	callbackStruct.inputProcRefCon=this;
	status = AudioUnitSetProperty(unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, kOutputBus, &callbackStruct, sizeof(callbackStruct));
	CHECK_AU_ERROR(status, "Error setting input buffer callback");
	status=AudioUnitInitialize(unit);
	CHECK_AU_ERROR(status, "Error initializing unit");
}

CAudioOutputAudioUnit::~CAudioOutputAudioUnit(){
	AudioUnitUninitialize(unit);
	AudioComponentInstanceDispose(unit);
}

void CAudioOutputAudioUnit::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
}

void CAudioOutputAudioUnit::Start(){
	isPlaying=true;
	OSStatus status=AudioOutputUnitStart(unit);
	CHECK_AU_ERROR(status, "Error starting AudioUnit");
}

void CAudioOutputAudioUnit::Stop(){
	isPlaying=false;
	OSStatus status=AudioOutputUnitStart(unit);
	CHECK_AU_ERROR(status, "Error stopping AudioUnit");
}

OSStatus CAudioOutputAudioUnit::BufferCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
	CAudioOutputAudioUnit* input=(CAudioOutputAudioUnit*) inRefCon;
	input->HandleBufferCallback(ioData);
	return noErr;
}

bool CAudioOutputAudioUnit::IsPlaying(){
	return isPlaying;
}

void CAudioOutputAudioUnit::HandleBufferCallback(AudioBufferList *ioData){
	int i;
	unsigned int k;
	int16_t absVal=0;
	for(i=0;i<ioData->mNumberBuffers;i++){
		AudioBuffer buf=ioData->mBuffers[i];
		if(!isPlaying){
			memset(buf.mData, 0, buf.mDataByteSize);
			return;
		}
		while(remainingDataSize<buf.mDataByteSize){
			assert(remainingDataSize+BUFFER_SIZE*2<10240);
			InvokeCallback(remainingData+remainingDataSize, BUFFER_SIZE*2);
			remainingDataSize+=BUFFER_SIZE*2;
		}
		memcpy(buf.mData, remainingData, buf.mDataByteSize);
		remainingDataSize-=buf.mDataByteSize;
		memmove(remainingData, remainingData+buf.mDataByteSize, remainingDataSize);
	}
}
