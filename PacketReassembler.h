//
// Created by Grishka on 19.03.2018.
//

#ifndef TGVOIP_PACKETREASSEMBLER_H
#define TGVOIP_PACKETREASSEMBLER_H

#include "MediaStreamItf.h"

namespace tgvoip {
	class PacketReassembler : public MediaStreamItf{
	public:
		PacketReassembler();
		virtual ~PacketReassembler();

		void Start(){};
		void Stop(){};

		void Reset();
		void AddPacket(unsigned char* data, size_t offset, size_t len, uint32_t pts);

	private:
		unsigned char* buffer;
		size_t currentSize;
		size_t finalSize;
	};
}

#endif //TGVOIP_PACKETREASSEMBLER_H
