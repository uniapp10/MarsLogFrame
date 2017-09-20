//
//  NSString+GXBDevice.h
//  GXBaseExample
//
//  Created by Vision on 2017/3/27.
//  Copyright © 2017年 guoxin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (GXBDevice)

+ (NSString *)gxb_deviceUUID;
+ (NSString *)gxb_deviceModel;
+ (NSString *)gxb_deviceName;
+ (NSString *)gxb_deviceSystemVersion;
+ (NSString *)gxb_deviceAppVersion;
+ (NSString *)gxb_deviceIPAdress;
@end
