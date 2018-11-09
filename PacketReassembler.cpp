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

void PacketReassembler::AddFragment(Buffer pkt, unsigned int fragmentIndex, unsigned int fragmentCount, uint32_t pts){
	//LOGD("add fragment: ts=%u, index=%u of %u", pts, fragmentIndex, fragmentCount);
	if(fragmentCount==0 || fragmentCount==1){
		callback(std::move(pkt), pts);
		return;
	}
	if(pts!=currentTimestamp){
		assert(fragmentCount<=255);
		currentTimestamp=pts;
		parts.clear();
		parts.resize(fragmentCount);
		currentPacketPartCount=fragmentCount;
	}

	if(fragmentIndex<currentPacketPartCount){
		parts[fragmentIndex]=std::move(pkt);
	}
	if(parts.size()<currentPacketPartCount)
		return;

	bool anyAreEmpty=false;
	for(Buffer& b:parts){
		if(b.Length()==0){
			anyAreEmpty=true;
			break;
		}
	}

	if(!anyAreEmpty){
		//LOGI("part count %u", (unsigned int)parts.size());
		BufferOutputStream out(10240);
		for(Buffer& b:parts){
			out.WriteBytes(b);
		}
		callback(Buffer(std::move(out)), currentTimestamp);
	}
}

void PacketReassembler::SetCallback(std::function<void(Buffer packet, uint32_t pts)> callback){
	this->callback=callback;
}
