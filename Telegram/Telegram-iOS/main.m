#import <UIKit/UIKit.h>
#import <dlfcn.h>

int main(int argc, char *argv[]) {
    /*NSString *basePath = [[NSString stringWithUTF8String:argv[0]] stringByDeletingLastPathComponent];
    void *Share = dlopen([[basePath stringByAppendingPathComponent:@"PlugIns/Share.appex/Share"] UTF8String], RTLD_LAZY);
    void *NotificationContent = dlopen([[basePath stringByAppendingPathComponent:@"PlugIns/NotificationContent.appex/NotificationContent"] UTF8String], RTLD_LAZY);
    sleep(1000);
    void *NotificationService = dlopen([[basePath stringByAppendingPathComponent:@"PlugIns/NotificationService.appex/NotificationService"] UTF8String], RTLD_LAZY);
    void *SiriIntents = dlopen([[basePath stringByAppendingPathComponent:@"PlugIns/SiriIntents.appex/SiriIntents"] UTF8String], RTLD_LAZY);
    void *Widget = dlopen([[basePath stringByAppendingPathComponent:@"PlugIns/Widget.appex/Widget"] UTF8String], RTLD_LAZY);
     1*/
    
    @autoreleasepool {
        return UIApplicationMain(argc, argv, @"Application", @"AppDelegate");
    }
}
