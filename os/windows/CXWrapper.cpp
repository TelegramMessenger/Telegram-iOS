#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <vector>
#include <string>
#include "CXWrapper.h"

using namespace libtgvoip;
using namespace Platform;
using namespace tgvoip;
using namespace Windows::Security::Cryptography;
using namespace Windows::Security::Cryptography::Core;
using namespace Windows::Storage::Streams;

//CryptographicHash^ MicrosoftCryptoImpl::sha1Hash;
//CryptographicHash^ MicrosoftCryptoImpl::sha256Hash;
HashAlgorithmProvider^ MicrosoftCryptoImpl::sha1Provider;
HashAlgorithmProvider^ MicrosoftCryptoImpl::sha256Provider;
SymmetricKeyAlgorithmProvider^ MicrosoftCryptoImpl::aesKeyProvider;

struct tgvoip_cx_data{
	VoIPControllerWrapper^ self;
};

VoIPControllerWrapper::VoIPControllerWrapper(){
	VoIPController::crypto.aes_ige_decrypt=MicrosoftCryptoImpl::AesIgeDecrypt;
	VoIPController::crypto.aes_ige_encrypt=MicrosoftCryptoImpl::AesIgeEncrypt;
	VoIPController::crypto.sha1=MicrosoftCryptoImpl::SHA1;
	VoIPController::crypto.sha256=MicrosoftCryptoImpl::SHA256;
	VoIPController::crypto.rand_bytes=MicrosoftCryptoImpl::RandBytes;
	controller=new VoIPController();
	tgvoip_cx_data* implData=(tgvoip_cx_data*)malloc(sizeof(tgvoip_cx_data));
	implData->self=this;
	controller->implData=implData;
	controller->SetStateCallback(VoIPControllerWrapper::OnStateChanged);
	stateCallback=nullptr;
}

VoIPControllerWrapper::~VoIPControllerWrapper(){
	((tgvoip_cx_data*)controller->implData)->self=nullptr;
	free(controller->implData);
	delete controller;
}

void VoIPControllerWrapper::Start(){
	controller->Start();
}

void VoIPControllerWrapper::Connect(){
	controller->Connect();
}

void VoIPControllerWrapper::SetPublicEndpoints(Windows::Foundation::Collections::IIterable<libtgvoip::Endpoint^>^ endpoints, bool allowP2P){
	Windows::Foundation::Collections::IIterator<libtgvoip::Endpoint^>^ iterator=endpoints->First();
	std::vector<tgvoip::Endpoint> eps;
	while(iterator->HasCurrent){
		libtgvoip::Endpoint^ _ep=iterator->Current;
		tgvoip::Endpoint ep;
		ep.id=_ep->id;
		ep.type=EP_TYPE_UDP_RELAY;
		char buf[128];
		if(_ep->ipv4){
			WideCharToMultiByte(CP_UTF8, 0, _ep->ipv4->Data(), -1, buf, sizeof(buf), NULL, NULL);
			ep.address=IPv4Address(buf);
		}
		if(_ep->ipv6){
			WideCharToMultiByte(CP_UTF8, 0, _ep->ipv6->Data(), -1, buf, sizeof(buf), NULL, NULL);
			ep.v6address=IPv6Address(buf);
		}
		ep.port=_ep->port;
		if(_ep->peerTag->Length!=16)
			throw ref new Platform::InvalidArgumentException("Peer tag must be exactly 16 bytes long");
		memcpy(ep.peerTag, _ep->peerTag->Data, 16);
		eps.push_back(ep);
	}
	controller->SetRemoteEndpoints(eps, allowP2P);
}

void VoIPControllerWrapper::SetNetworkType(int type){
	controller->SetNetworkType(type);
}

void VoIPControllerWrapper::SetStateCallback(IStateCallback^ callback){
	stateCallback=callback;
}

void VoIPControllerWrapper::SetMicMute(bool mute){
	controller->SetMicMute(mute);
}

void VoIPControllerWrapper::SetEncryptionKey(const Platform::Array<uint8>^ key, bool isOutgoing){
	if(key->Length!=256)
		throw ref new Platform::InvalidArgumentException("Encryption key must be exactly 256 bytes long");
	controller->SetEncryptionKey((char*)key->Data, isOutgoing);
}

Platform::String^ VoIPControllerWrapper::GetDebugString(){
	char abuf[10240];
	controller->GetDebugString(abuf, sizeof(abuf));
	wchar_t wbuf[10240];
	MultiByteToWideChar(CP_UTF8, 0, abuf, -1, wbuf, sizeof(wbuf));
	return ref new Platform::String(wbuf);
}

Platform::String^ VoIPControllerWrapper::GetDebugLog(){
	std::string log=controller->GetDebugLog();
	size_t len=sizeof(wchar_t)*(log.length()+1);
	wchar_t* wlog=(wchar_t*)malloc(len);
	MultiByteToWideChar(CP_UTF8, 0, log.c_str(), -1, wlog, len/sizeof(wchar_t));
	Platform::String^ res=ref new Platform::String(wlog);
	free(wlog);
	return res;
}

int VoIPControllerWrapper::GetLastError(){
	return controller->GetLastError();
}

Platform::String^ VoIPControllerWrapper::GetVersion(){
	const char* v=VoIPController::GetVersion();
	wchar_t buf[32];
	MultiByteToWideChar(CP_UTF8, 0, v, -1, buf, sizeof(buf));
	return ref new Platform::String(buf);
}

void VoIPControllerWrapper::OnStateChanged(VoIPController* c, int state){
	((tgvoip_cx_data*)c->implData)->self->OnStateChangedInternal(state);
}

void VoIPControllerWrapper::OnStateChangedInternal(int state){
	if(stateCallback)
		stateCallback->OnCallStateChanged(state);
}

void MicrosoftCryptoImpl::AesIgeEncrypt(uint8_t* in, uint8_t* out, size_t len, uint8_t* key, uint8_t* iv){
	Platform::Array<uint8>^ keybuf=ref new Platform::Array<uint8>(16);
	memcpy(keybuf->Data, key, 16);
	CryptographicKey^ _key=aesKeyProvider->CreateSymmetricKey(CryptographicBuffer::CreateFromByteArray(keybuf));
	Platform::Array<uint8>^ tmpIn=ref new Platform::Array<uint8>(16);
	Platform::Array<uint8>^ tmpOut=ref new Platform::Array<uint8>(16);
	uint8_t* xPrev=iv+16;
	uint8_t* yPrev=iv;
	for(size_t offset=0;offset<len;offset+=16){
		uint8_t* y=tmpIn->Data;
		uint8_t* x=in+offset;
		XorInt128(x, yPrev, y);
		CryptographicBuffer::CopyToByteArray(CryptographicEngine::Encrypt(_key, CryptographicBuffer::CreateFromByteArray(tmpIn), nullptr), &tmpOut);
		XorInt128(tmpOut->Data, xPrev, y);
		memcpy(xPrev, x, 16);
		memcpy(yPrev, y, 16);
		memcpy(out+offset, y, 16);
	}
}

void MicrosoftCryptoImpl::AesIgeDecrypt(uint8_t* in, uint8_t* out, size_t len, uint8_t* key, uint8_t* iv){
	Platform::Array<uint8>^ keybuf=ref new Platform::Array<uint8>(16);
	memcpy(keybuf->Data, key, 16);
	CryptographicKey^ _key=aesKeyProvider->CreateSymmetricKey(CryptographicBuffer::CreateFromByteArray(keybuf));
	Platform::Array<uint8>^ tmpIn=ref new Platform::Array<uint8>(16);
	Platform::Array<uint8>^ tmpOut=ref new Platform::Array<uint8>(16);
	uint8_t* xPrev=iv;
	uint8_t* yPrev=iv+16;
	for(size_t offset=0;offset<len;offset+=16){
		uint8_t* y=tmpIn->Data;
		uint8_t* x=in+offset;
		XorInt128(x, yPrev, y);
		CryptographicBuffer::CopyToByteArray(CryptographicEngine::Decrypt(_key, CryptographicBuffer::CreateFromByteArray(tmpIn), nullptr), &tmpOut);
		XorInt128(tmpOut->Data, xPrev, y);
		memcpy(xPrev, x, 16);
		memcpy(yPrev, y, 16);
		memcpy(out+offset, y, 16);
	}
}

void MicrosoftCryptoImpl::SHA1(uint8_t* msg, size_t len, uint8_t* out){
	//EnterCriticalSection(&hashMutex);

	Platform::Array<uint8>^ arr=ref new Platform::Array<uint8>(len);
	memcpy(arr->Data, msg, len);
	CryptographicHash^ hash=sha1Provider->CreateHash();
	hash->Append(CryptographicBuffer::CreateFromByteArray(arr));
	IBuffer^ res=hash->GetValueAndReset();
	CryptographicBuffer::CopyToByteArray(res, &arr);
	memcpy(out, arr->Data, res->Length);

	//LeaveCriticalSection(&hashMutex);
}

void MicrosoftCryptoImpl::SHA256(uint8_t* msg, size_t len, uint8_t* out){
	//EnterCriticalSection(&hashMutex);

	Platform::Array<uint8>^ arr=ref new Platform::Array<uint8>(len);
	memcpy(arr->Data, msg, len);
	CryptographicHash^ hash=sha256Provider->CreateHash();
	hash->Append(CryptographicBuffer::CreateFromByteArray(arr));
	IBuffer^ res=hash->GetValueAndReset();
	CryptographicBuffer::CopyToByteArray(res, &arr);
	memcpy(out, arr->Data, res->Length);

	//LeaveCriticalSection(&hashMutex);
}

void MicrosoftCryptoImpl::RandBytes(uint8_t* buffer, size_t len){
	Platform::Array<uint8>^ a=ref new Platform::Array<uint8>(len);
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::GenerateRandom(len), &a);
	memcpy(buffer, a->Data, len);
}

void MicrosoftCryptoImpl::Init(){
	/*sha1Hash=HashAlgorithmProvider::OpenAlgorithm(HashAlgorithmNames::Sha1)->CreateHash();
	sha256Hash=HashAlgorithmProvider::OpenAlgorithm(HashAlgorithmNames::Sha256)->CreateHash();*/
	sha1Provider=HashAlgorithmProvider::OpenAlgorithm(HashAlgorithmNames::Sha1);
	sha256Provider=HashAlgorithmProvider::OpenAlgorithm(HashAlgorithmNames::Sha256);
	aesKeyProvider=SymmetricKeyAlgorithmProvider::OpenAlgorithm(SymmetricAlgorithmNames::AesEcb);
}

void MicrosoftCryptoImpl::XorInt128(uint8_t* a, uint8_t* b, uint8_t* out){
	uint64_t* _a=reinterpret_cast<uint64_t*>(a);
	uint64_t* _b=reinterpret_cast<uint64_t*>(b);
	uint64_t* _out=reinterpret_cast<uint64_t*>(out);
	_out[0]=_a[0]^_b[0];
	_out[1]=_a[1]^_b[1];
}

/*Platform::String^ VoIPControllerWrapper::TestAesIge(){
	MicrosoftCryptoImpl::Init();
	Platform::String^ res="";
	Platform::Array<uint8>^ data=ref new Platform::Array<uint8>(32);
	Platform::Array<uint8>^ out=ref new Platform::Array<uint8>(32);
	Platform::Array<uint8>^ key=ref new Platform::Array<uint8>(16);
	Platform::Array<uint8>^ iv=ref new Platform::Array<uint8>(32);
	
	
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("0000000000000000000000000000000000000000000000000000000000000000"), &data);
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"), &iv);
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("000102030405060708090a0b0c0d0e0f"), &key);
	MicrosoftCryptoImpl::AesIgeEncrypt(data->Data, out->Data, 32, key->Data, iv->Data);
	res+=CryptographicBuffer::EncodeToHexString(CryptographicBuffer::CreateFromByteArray(out));
	res+="\n";

	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("1A8519A6557BE652E9DA8E43DA4EF4453CF456B4CA488AA383C79C98B34797CB"), &data);
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"), &iv);
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("000102030405060708090a0b0c0d0e0f"), &key);
	MicrosoftCryptoImpl::AesIgeDecrypt(data->Data, out->Data, 32, key->Data, iv->Data);
	res+=CryptographicBuffer::EncodeToHexString(CryptographicBuffer::CreateFromByteArray(out));
	res+="\n";

	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("99706487A1CDE613BC6DE0B6F24B1C7AA448C8B9C3403E3467A8CAD89340F53B"), &data);
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("6D656E746174696F6E206F6620494745206D6F646520666F72204F70656E5353"), &iv);
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("5468697320697320616E20696D706C65"), &key);
	MicrosoftCryptoImpl::AesIgeEncrypt(data->Data, out->Data, 32, key->Data, iv->Data);
	res+=CryptographicBuffer::EncodeToHexString(CryptographicBuffer::CreateFromByteArray(out));
	res+="\n";

	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("4C2E204C6574277320686F70652042656E20676F74206974207269676874210A"), &data);
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("6D656E746174696F6E206F6620494745206D6F646520666F72204F70656E5353"), &iv);
	CryptographicBuffer::CopyToByteArray(CryptographicBuffer::DecodeFromHexString("5468697320697320616E20696D706C65"), &key);
	MicrosoftCryptoImpl::AesIgeDecrypt(data->Data, out->Data, 32, key->Data, iv->Data);
	res+=CryptographicBuffer::EncodeToHexString(CryptographicBuffer::CreateFromByteArray(out));
	return res;
}*/