//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <stdlib.h>
#include <stdio.h>
#include "AudioInputAudioUnitOSX.h"
#include "../../logging.h"
#include "../../audio/Resampler.h"

#define BUFFER_SIZE 960
#define CHECK_AU_ERROR(res, msg) if(res!=noErr){ LOGE("input: " msg": OSStatus=%d", (int)res); failed=true; return; }

#define kOutputBus 0
#define kInputBus 1


CAudioInputAudioUnit::CAudioInputAudioUnit(){
	remainingDataSize=0;
	isRecording=false;
	
	OSStatus status;
	AudioComponentDescription inputDesc={
		.componentType = kAudioUnitType_Output, .componentSubType = kAudioUnitSubType_HALOutput, .componentFlags = 0, .componentFlagsMask = 0,
		.componentManufacturer = kAudioUnitManufacturer_Apple
	};
	AudioComponent component=AudioComponentFindNext(NULL, &inputDesc);
	status=AudioComponentInstanceNew(component, &unit);
	CHECK_AU_ERROR(status, "Error creating AudioUnit");
	
	UInt32 flag=0;
	status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error enabling AudioUnit output");
	flag=1;
	status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, sizeof(flag));
	CHECK_AU_ERROR(status, "Error enabling AudioUnit input");
	
	UInt32 size=sizeof(AudioDeviceID);
	AudioDeviceID inputDevice;
	AudioObjectPropertyAddress propertyAddress;
	propertyAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice;
	propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
	propertyAddress.mElement = kAudioObjectPropertyElementMaster;
	
	UInt32 propsize = sizeof(AudioDeviceID);
	status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &propsize, &inputDevice);
	CHECK_AU_ERROR(status, "Error getting default input device");
 
	status =AudioUnitSetProperty(unit,
							  kAudioOutputUnitProperty_CurrentDevice,
							  kAudioUnitScope_Global,
							  kInputBus,
							  &inputDevice,
							  size);
	CHECK_AU_ERROR(status, "Error setting input device");
	
	AudioStreamBasicDescription hardwareFormat;
	size=sizeof(hardwareFormat);
	status=AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kInputBus, &hardwareFormat, &size);
	CHECK_AU_ERROR(status, "Error getting hardware format");
	
	AudioStreamBasicDescription desiredFormat={
		.mSampleRate=hardwareFormat.mSampleRate, .mFormatID=kAudioFormatLinearPCM, .mFormatFlags=kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
		.mFramesPerPacket=1, .mChannelsPerFrame=1, .mBitsPerChannel=16, .mBytesPerPacket=2, .mBytesPerFrame=2
	};
	hardwareSampleRate=hardwareFormat.mSampleRate;
	
	status=AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBus, &desiredFormat, sizeof(desiredFormat));
	CHECK_AU_ERROR(status, "Error setting format");
	
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc = CAudioInputAudioUnit::BufferCallback;
	callbackStruct.inputProcRefCon=this;
	status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, kInputBus, &callbackStruct, sizeof(callbackStruct));
	CHECK_AU_ERROR(status, "Error setting input buffer callback");
	status=AudioUnitInitialize(unit);
	CHECK_AU_ERROR(status, "Error initializing unit");
	
	inBufferList.mBuffers[0].mData=malloc(10240);
	inBufferList.mBuffers[0].mDataByteSize=10240;
	inBufferList.mNumberBuffers=1;
}

CAudioInputAudioUnit::~CAudioInputAudioUnit(){
	AudioUnitUninitialize(unit);
	AudioComponentInstanceDispose(unit);
	free(inBufferList.mBuffers[0].mData);
}

void CAudioInputAudioUnit::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
}

void CAudioInputAudioUnit::Start(){
	isRecording=true;
	OSStatus status=AudioOutputUnitStart(unit);
	CHECK_AU_ERROR(status, "Error starting AudioUnit");
}

void CAudioInputAudioUnit::Stop(){
	isRecording=false;
	OSStatus status=AudioOutputUnitStart(unit);
	CHECK_AU_ERROR(status, "Error stopping AudioUnit");
}

OSStatus CAudioInputAudioUnit::BufferCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
	CAudioInputAudioUnit* input=(CAudioInputAudioUnit*) inRefCon;
	input->inBufferList.mBuffers[0].mDataByteSize=10240;
	OSStatus res=AudioUnitRender(input->unit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &input->inBufferList);
	input->HandleBufferCallback(&input->inBufferList);
	return noErr;
}

void CAudioInputAudioUnit::HandleBufferCallback(AudioBufferList *ioData){
	int i;
	for(i=0;i<ioData->mNumberBuffers;i++){
		AudioBuffer buf=ioData->mBuffers[i];
		size_t len=buf.mDataByteSize;
		if(hardwareSampleRate!=48000){
			len=tgvoip::audio::Resampler::Convert((int16_t*)buf.mData, (int16_t*)(remainingData+remainingDataSize), buf.mDataByteSize/2, (10240-(buf.mDataByteSize+remainingDataSize))/2, 48000, hardwareSampleRate)*2;
		}else{
			assert(remainingDataSize+buf.mDataByteSize<10240);
			memcpy(remainingData+remainingDataSize, buf.mData, buf.mDataByteSize);
		}
		remainingDataSize+=len;
		while(remainingDataSize>=BUFFER_SIZE*2){
			InvokeCallback((unsigned char*)remainingData, BUFFER_SIZE*2);
			remainingDataSize-=BUFFER_SIZE*2;
			if(remainingDataSize>0){
				memmove(remainingData, remainingData+(BUFFER_SIZE*2), remainingDataSize);
			}
		}
	}
}
