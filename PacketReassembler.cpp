//
// Created by Grishka on 19.03.2018.
//

#include "PacketReassembler.h"
#include "logging.h"

#include <assert.h>

using namespace tgvoip;

PacketReassembler::PacketReassembler(){

}

PacketReassembler::~PacketReassembler(){

}

void PacketReassembler::Reset(){

}

void PacketReassembler::AddFragment(Buffer pkt, unsigned int fragmentIndex, unsigned int fragmentCount, uint32_t pts, bool keyframe){
	//LOGD("add fragment: ts=%u, index=%u of %u", pts, fragmentIndex, fragmentCount);
	if(pts!=currentTimestamp){
		assert(fragmentCount<=255);
		currentTimestamp=pts;
		/*for(Buffer& b:parts){
			if(!b.IsEmpty())
				b=Buffer();
		}*/
		currentPacketPartCount=fragmentCount;
		currentIsKeyframe=keyframe;
		receivedPartCount=0;
	}
	if(fragmentCount==0 || fragmentCount==1){
		callback(std::move(pkt), pts, keyframe);
		return;
	}

	if(fragmentIndex<currentPacketPartCount){
		parts[fragmentIndex]=std::move(pkt);
	}
	if(parts.size()<currentPacketPartCount)
		return;

	receivedPartCount++;

	bool anyAreEmpty=false;
	for(int i=0;i<currentPacketPartCount;i++){
		if(parts[i].IsEmpty()){
			anyAreEmpty=true;
			break;
		}
	}

	if(!anyAreEmpty && receivedPartCount==currentPacketPartCount){
		//LOGI("part count %u", (unsigned int)parts.size());
		BufferOutputStream out(10240);
		for(int i=0;i<currentPacketPartCount;i++){
			out.WriteBytes(parts[i]);
			parts[i]=Buffer();
		}
		//LOGI("reassembled %u parts, %u bytes", (unsigned int)receivedPartCount, out.GetLength());
		callback(Buffer(std::move(out)), currentTimestamp, currentIsKeyframe);
		currentPacketPartCount=0;
		currentTimestamp=0;
	}
}

void PacketReassembler::SetCallback(std::function<void(Buffer packet, uint32_t pts, bool keyframe)> callback){
	this->callback=callback;
}
