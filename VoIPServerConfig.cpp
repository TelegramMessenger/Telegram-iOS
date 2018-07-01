//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "VoIPServerConfig.h"
#include <stdlib.h>
#include "logging.h"
#include <sstream>
#include <locale>

using namespace tgvoip;

ServerConfig* ServerConfig::sharedInstance=NULL;

ServerConfig::ServerConfig(){
}

ServerConfig::~ServerConfig(){
}

ServerConfig *ServerConfig::GetSharedInstance(){
	if(!sharedInstance)
		sharedInstance=new ServerConfig();
	return sharedInstance;
}

bool ServerConfig::GetBoolean(std::string name, bool fallback){
	MutexGuard sync(mutex);
	if(ContainsKey(name)){
		std::string val=config[name];
		if(val=="true")
			return true;
		if(val=="false")
			return false;
	}
	return fallback;
}

double ServerConfig::GetDouble(std::string name, double fallback){
	MutexGuard sync(mutex);
	if(ContainsKey(name)){
		std::string val=config[name];
		std::istringstream stm(val);
		double rval=fallback;
		stm.imbue(std::locale("C"));
		stm >> rval;
		if(!stm.fail())
			return rval;
	}
	return fallback;
}

int32_t ServerConfig::GetInt(std::string name, int32_t fallback){
	MutexGuard sync(mutex);
	if(ContainsKey(name)){
		std::string val=config[name];
		char* end;
		const char* start=val.c_str();
		int32_t d=strtol(start, &end, 0);
		if(end!=start){
			return d;
		}
	}
	return fallback;
}

std::string ServerConfig::GetString(std::string name, std::string fallback){
	MutexGuard sync(mutex);
	if(ContainsKey(name))
		return config[name];
	return fallback;
}

void ServerConfig::Update(std::map<std::string, std::string> newValues){
	MutexGuard sync(mutex);
	LOGD("=== Updating voip config ===");
	config.clear();
	for(std::map<std::string, std::string>::iterator itr=newValues.begin();itr!=newValues.end();++itr){
		std::string key=itr->first;
		std::string val=itr->second;
		LOGV("%s -> %s", key.c_str(), val.c_str());
		config[key]=val;
	}
}

void ServerConfig::Update(const char **values, int count) {
    std::map<std::string, std::string> result;
    for (int i = 0; i < count / 2; i++) {
        result[values[i * 2 + 0]] = std::string(values[i * 2 + 1]);
    }
    Update(result);
}


bool ServerConfig::ContainsKey(std::string key){
	return config.find(key)!=config.end();
}


