//
// Created by Grishka on 19.03.2018.
//

#ifndef TGVOIP_PACKETREASSEMBLER_H
#define TGVOIP_PACKETREASSEMBLER_H

#include <vector>
#include <functional>
#include <unordered_map>

#include "Buffers.h"

namespace tgvoip {
	class PacketReassembler{
	public:
		PacketReassembler();
		virtual ~PacketReassembler();

		void Reset();
		void AddFragment(Buffer pkt, unsigned int fragmentIndex, unsigned int fragmentCount, uint32_t pts, bool keyframe);
		void SetCallback(std::function<void(Buffer packet, uint32_t pts, bool keyframe)> callback);

	private:
		uint32_t currentTimestamp;
		unsigned int currentPacketPartCount=0;
		std::array<Buffer, 255> parts;
		std::function<void(Buffer, uint32_t, bool)> callback;
		bool currentIsKeyframe;
		unsigned int receivedPartCount=0;
	};
}

#endif //TGVOIP_PACKETREASSEMBLER_H
