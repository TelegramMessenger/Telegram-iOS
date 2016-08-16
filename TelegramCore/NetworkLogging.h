#ifndef Telegram_NetworkLogging_h
#define Telegram_NetworkLogging_h

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

void NetworkRegisterLoggingFunction();

void setBridgingTraceFunction(void (*)(NSString *, NSString *));

#endif
