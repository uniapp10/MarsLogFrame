//
//  NSString+GXBDevice.m
//  GXBaseExample
//
//  Created by Vision on 2017/3/27.
//  Copyright © 2017年 guoxin. All rights reserved.
//

#import "NSString+GXBDevice.h"
#import <UIKit/UIKit.h>
#import <arpa/inet.h>
#import <ifaddrs.h>

@implementation NSString (GXBDevice)

+ (NSString *)gxb_deviceUUID {
    CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuid = (NSString *)CFBridgingRelease(CFUUIDCreateString (kCFAllocatorDefault,uuidRef));
    
    uuid =  [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return uuid;
}

+ (NSString *)gxb_deviceModel {
    return [UIDevice currentDevice].model;
}

+ (NSString *)gxb_deviceName {
    return @"ios";
}

+ (NSString *)gxb_deviceSystemVersion {
    return [UIDevice currentDevice].systemVersion;
}

+ (NSString *)gxb_deviceAppVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

+ (NSString *)gxb_deviceIPAdress {
    NSString *address = @"an error occurred when obtaining ip address";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    success = getifaddrs(&interfaces);
    
    if (success == 0)
    {
        // 0 表示获取成功
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if( temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    
    return address;
}
@end
