//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "VoIPServerConfig.h"
#include <stdlib.h>
#include "logging.h"

CVoIPServerConfig* CVoIPServerConfig::sharedInstance=NULL;

CVoIPServerConfig::CVoIPServerConfig(){
	init_mutex(mutex);
}

CVoIPServerConfig::~CVoIPServerConfig(){
	free_mutex(mutex);
}

CVoIPServerConfig *CVoIPServerConfig::GetSharedInstance(){
	if(!sharedInstance)
		sharedInstance=new CVoIPServerConfig();
	return sharedInstance;
}

bool CVoIPServerConfig::GetBoolean(std::string name, bool fallback){
	CMutexGuard sync(mutex);
	if(ContainsKey(name)){
		std::string val=config[name];
		if(val=="true")
			return true;
		if(val=="false")
			return false;
	}
	return fallback;
}

double CVoIPServerConfig::GetDouble(std::string name, double fallback){
	CMutexGuard sync(mutex);
	if(ContainsKey(name)){
		std::string val=config[name];
		char* end;
		const char* start=val.c_str();
		double d=strtod(start, &end);
		if(end!=start){
			return d;
		}
	}
	return fallback;
}

int32_t CVoIPServerConfig::GetInt(std::string name, int32_t fallback){
	CMutexGuard sync(mutex);
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

std::string CVoIPServerConfig::GetString(std::string name, std::string fallback){
	CMutexGuard sync(mutex);
	if(ContainsKey(name))
		return config[name];
	return fallback;
}

void CVoIPServerConfig::Update(std::map<std::string, std::string> newValues){
	CMutexGuard sync(mutex);
	LOGD("=== Updating voip config ===");
	config.clear();
	for(std::map<std::string, std::string>::iterator itr=newValues.begin();itr!=newValues.end();++itr){
		std::string key=itr->first;
		std::string val=itr->second;
		LOGV("%s -> %s", key.c_str(), val.c_str());
		config[key]=val;
	}
}

void CVoIPServerConfig::Update(const char **values, int count) {
    std::map<std::string, std::string> result;
    for (int i = 0; i < count / 2; i++) {
        result[values[i * 2 + 0]] = std::string(values[i * 2 + 1]);
    }
    Update(result);
}


bool CVoIPServerConfig::ContainsKey(std::string key){
	return config.find(key)!=config.end();
}


