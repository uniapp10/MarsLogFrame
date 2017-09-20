//
//  JJXlog.m
//  iOSDemoXlog
//
//  Created by zhudong on 2017/7/25.
//
//

#import "JJXlog.h"
#import "xlogger.h"
#import "appender.h"
#import "xloggerbase.h"
#import <sys/xattr.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

#import <sys/socket.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import "LogUtil.h"
#import "AFNetworkReachabilityManager.h"
#import <CoreLocation/CoreLocation.h>

#import <arpa/inet.h>
#import <ifaddrs.h>

#define keyNetWorkType @"keyNetWorkType"

@interface JJXlog ()<CLLocationManagerDelegate>

@property (nonatomic, strong) NSTimer *logTimer;
@property (nonatomic,strong) CLLocationManager *locMgr;
@property (nonatomic,strong) NSArray *keyWords;

@end


@implementation JJXlog

+ (instancetype)shareXLog{
    static JJXlog *log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = [[JJXlog alloc] init];
    });
    return log;
}

- (void)setLoginName:(NSString *)name{
    
    appender_close();
    NSString* logPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/log"];
    
    // set do not backup for logpath
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr([logPath UTF8String], attrName, &attrValue, sizeof(attrValue), 0, 0);
    
    // init xlog
#if DEBUG
    xlogger_SetLevel(kLevelDebug);
    appender_set_console_log(true);
#else
    xlogger_SetLevel(kLevelInfo);
    appender_set_console_log(false);
#endif
    NSString *uuid = [self gxb_deviceUUID];
    if (uuid.length == 0) {
        uuid = @"noUUID";
    }
    NSMutableString *totalName = [NSMutableString string];
    [totalName appendString:uuid];
    if (name.length > 0) {
        [totalName appendString:[NSString stringWithFormat:@"_%@", name]];
    }else{
        [totalName appendString:@"_"];
    }
    const char *cTotalName = [totalName cStringUsingEncoding:NSUTF8StringEncoding];
    appender_set_max_file_size(512);
    appender_open(kAppednerAsync, [logPath UTF8String], cTotalName);
}

- (void)setKeyWords:(NSArray *)keys{
    self.keyWords = keys;
}

- (void)start{
    NSString *deviceIP;
    NSString *model;
    NSString *sysVersion;
    NSString *pfLanguageCode;
    NSString *netType;
    NSMutableString *nameM;
    NSString *appVersion;
    NSMutableString *infoM;
    @try {
        deviceIP = [self gxb_deviceIPAdress];
        model = [self gxb_deviceModel];
        sysVersion = [self gxb_deviceSystemVersion];
        pfLanguageCode = [NSLocale preferredLanguages][0];
#pragma clang diagnostic push
        
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        Class cls = NSClassFromString(@"LSApplicationWorkspace");
        id s = [(id)cls performSelector:NSSelectorFromString(@"defaultWorkspace")];
        NSArray *arr = [s performSelector:NSSelectorFromString(@"allInstalledApplications")];
        
        if (arr.count > 0) {
            nameM = [[NSMutableString alloc] initWithString:@"("];
            for (int i = 0; i < arr.count; i++) {
                NSString *localizedName = [arr[i] performSelector:NSSelectorFromString(@"localizedName")];
                
                if (self.keyWords.count > 0) {
                    for (NSString *key in self.keyWords) {
                        if ([localizedName containsString:key]){
                            [nameM appendString:@","];
                        }
                    }
                }else{
                    if ([localizedName containsString:@"金"] || [localizedName containsString:@"银"]) {
                        [nameM appendString:localizedName];
                        [nameM appendString:@","];
                    }
                }
            }
            [nameM appendString:@")"];
        }
        
        netType = [self getNetWorkType];
        appVersion = [self gxb_deviceAppVersion];
        infoM = [[NSMutableString alloc] init];
        if (deviceIP) {
            [infoM appendString:[NSString stringWithFormat:@"%@,", deviceIP]];
        }
        if (model) {
            [infoM appendString:[NSString stringWithFormat:@"%@,", model]];
        }
        if (sysVersion) {
            [infoM appendString:[NSString stringWithFormat:@"%@,", sysVersion]];
        }
        if (pfLanguageCode) {
            [infoM appendString:[NSString stringWithFormat:@"%@,", pfLanguageCode]];
        }
        if (nameM) {
            [infoM appendString:[NSString stringWithFormat:@"%@,", nameM]];
        }
        if (netType) {
            [infoM appendString:[NSString stringWithFormat:@"%@,", netType]];
        }
        [infoM appendString:@"AppStore,"];
        if (appVersion) {
            [infoM appendString:[NSString stringWithFormat:@"%@", appVersion]];
        }
#pragma clang diagnostic pop
    } @catch (NSException *exception) {
        LOG_INFO("start", infoM);
        LOG_INFO("start", @"获取启动不完整");
    } @finally {
        LOG_INFO("start", infoM);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(netWorkChanged) name:AFNetworkingReachabilityDidChangeNotification object:nil];
        [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    }
    
}

- (void)stop{
    LOG_INFO("stop", @" ");
    appender_close();
    [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
}

- (void)flush{
    appender_flush();
}

- (void)setTimeInterval:(int)time{
    if (self.logTimer) {
        [self.logTimer invalidate];
        self.logTimer = nil;
    }
    self.logTimer = [NSTimer timerWithTimeInterval:time repeats:true block:^(NSTimer * _Nonnull timer) {
        [self upload];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.logTimer forMode:NSRunLoopCommonModes];
    
}

- (void)upload{
    appender_flush();
    
    NSString* logPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/log"];
    NSFileManager *fileM = [NSFileManager defaultManager];
    
    NSArray *subPaths = [fileM contentsOfDirectoryAtPath:logPath error:nil];
    NSLock *lock = [[NSLock alloc] init];
    for (NSString *fileName in subPaths) {
        if([fileName hasSuffix:@".xlog"]){
            //大于1M,等到wifi网络上传
            NSString *filePath = [logPath stringByAppendingPathComponent:fileName];
            NSDictionary * attributes = [fileM attributesOfItemAtPath:filePath error:nil];
            NSNumber *fileSize = [attributes objectForKey:NSFileSize];
            if ([fileSize integerValue] > 1048576 && (![[self getNetWorkType] isEqualToString:@"WIFI"])) {
                return;
            }
            [lock lock];
            NSData *fileData = [NSData dataWithContentsOfFile:filePath];
            NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
            NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
            NSString *app_Name = [infoDictionary objectForKey:@"CFBundleDisplayName"];
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://192.168.100.140:50070/upload?appName=%@", bundleIdentifier]]];
            request.HTTPMethod = @"POST";
            
            NSMutableArray *arrM = [NSMutableArray array];
            [arrM addObject:fileData];
            
            NSMutableString *dataBody = [NSMutableString string];
            
            [dataBody appendFormat:@"--3a332b51-852d-40ae-8ceb-2a95c39f0fed\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: application/octet-stream\r\nContent-Length: %zd\r\n\r\n",fileName, fileData.length];
            
            NSMutableData *fileDataM = [NSMutableData dataWithData:[dataBody dataUsingEncoding:NSASCIIStringEncoding]];
            [fileDataM appendData:fileData];
            [fileDataM appendData:[@"\r\n--3a332b51-852d-40ae-8ceb-2a95c39f0fed--" dataUsingEncoding:NSASCIIStringEncoding]];
            [request setValue:@"multipart/form-data; boundary=3a332b51-852d-40ae-8ceb-2a95c39f0fed" forHTTPHeaderField:@"content-type"];
            [request setValue:[NSString stringWithFormat:@"%zd", fileDataM.length] forHTTPHeaderField:@"Content-Length"];
            request.HTTPBody = fileDataM;
            
            [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                [lock unlock];
                if (data == nil) {
                    return ;
                }
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if(error || dict[@"success"] == 0 || dict[@"value"] == nil){
                    return ;
                }
                NSString *fileName1 = dict[@"value"];
                NSString *filePath1 = [logPath stringByAppendingPathComponent:fileName1];
                [fileM removeItemAtPath:filePath1 error:nil];
            }] resume];
        }
    }
}

- (void)cancelTime{
    [self.logTimer invalidate];
    self.logTimer = nil;
}

- (void)netWorkChanged{
    
    NSString *networkType = [self getNetWorkType];
    if (networkType.length > 0) {
        NSString *lastNetworkType = [[NSUserDefaults standardUserDefaults] objectForKey:keyNetWorkType];
        if (![networkType isEqualToString:lastNetworkType]) {
            [[NSUserDefaults standardUserDefaults] setObject:networkType forKey:keyNetWorkType];
            [[NSUserDefaults standardUserDefaults] synchronize];
            LOG_INFO("netChange", [self getNetWorkType]);
        }
    }
}


- (NSString *)getNetWorkType
{
    NSString *strNetworkType = @"";
    struct sockaddr_storage zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.ss_len = sizeof(zeroAddress);
    zeroAddress.ss_family = AF_INET;
    
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;
    
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
    if (!didRetrieveFlags)
    {
        return strNetworkType;
    }
    
    //没有网络
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        return @"NoNet";
    }
    
    if ((flags &kSCNetworkReachabilityFlagsConnectionRequired) ==0)
    {
        strNetworkType = @"WIFI";
    }
    
    if (
        ((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) !=0) ||
        (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) !=0
        )
    {
        if ((flags &kSCNetworkReachabilityFlagsInterventionRequired) ==0)
        {
            strNetworkType = @"WIFI";
        }
    }
    
    if ((flags &kSCNetworkReachabilityFlagsIsWWAN) ==kSCNetworkReachabilityFlagsIsWWAN)
    {
        if ([[[UIDevice currentDevice] systemVersion]floatValue] >=7.0)
        {
            CTTelephonyNetworkInfo * info = [[CTTelephonyNetworkInfo alloc]init];
            NSString *currentRadioAccessTechnology = info.currentRadioAccessTechnology;
            
            if (currentRadioAccessTechnology)
            {
                if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyLTE])
                {
                    strNetworkType =  @"4G";
                }
                else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyEdge] || [currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyGPRS])
                {
                    strNetworkType =  @"2G";
                }
                else
                {
                    strNetworkType =  @"3G";
                }
            }
        }
        else
        {
            if((flags &kSCNetworkReachabilityFlagsReachable) ==kSCNetworkReachabilityFlagsReachable)
            {
                if ((flags &kSCNetworkReachabilityFlagsTransientConnection) ==kSCNetworkReachabilityFlagsTransientConnection)
                {
                    if((flags &kSCNetworkReachabilityFlagsConnectionRequired) ==kSCNetworkReachabilityFlagsConnectionRequired)
                    {
                        strNetworkType = @"2G";
                    }
                    else
                    {
                        strNetworkType = @"3G";
                    }
                }
            }
        }
    }
    
    
    if ([strNetworkType isEqualToString:@""]) {
        strNetworkType = @"WWAN";
    }
    
//    NSLog(@"GetNetWorkType() strNetworkType :  %@", strNetworkType);
    
    return strNetworkType;
}

- (void)openLocation{
    [self.locMgr requestWhenInUseAuthorization];
    if ([CLLocationManager locationServicesEnabled] &&
        [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied) {
        self.locMgr.distanceFilter = 1000;
        self.locMgr.desiredAccuracy = kCLLocationAccuracyBest;
        self.locMgr.delegate = self;
        [self.locMgr startUpdatingLocation];
    }else{
        LOG_INFO("gpsChange", @"获取定位授权失败");
    }
}

- (void)requestLocation{
    
     if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 10.0) {
         NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
         NSString *urlStr = [NSString stringWithFormat:@"Prefs:root=Privacy&path=LOCATION&root=%@", appIdentifier];
         NSURL*url = [NSURL URLWithString:urlStr];
         Class LSApplicationWorkspace = NSClassFromString(@"LSApplicationWorkspace");
         [[LSApplicationWorkspace performSelector:@selector(defaultWorkspace)] performSelector:@selector(openSensitiveURL:withOptions:) withObject:url withObject:nil];
     }else{
         NSURL *url = [NSURL URLWithString:@"prefs:root=LOCATION_SERVICES"];
         if([[UIApplication sharedApplication] canOpenURL:url]) {
             NSURL*url =[NSURL URLWithString:UIApplicationOpenSettingsURLString];
             [[UIApplication sharedApplication] openURL:url];
         }
     }
     
}

#pragma mark - CLLocationManagerDelegate

//- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
//    NSLog(@"changed!");
//}
- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations{
    
    CLLocation *loc = [locations firstObject];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:loc completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (!error) {
            NSMutableString *locAdress = [NSMutableString string];
            if ([placemarks count] > 0) {
                CLPlacemark *placemark = [placemarks firstObject];
                NSString *city = placemark.locality;
                if (!city) {
                    city = placemark.administrativeArea;
                }
                if (city) {
                    [locAdress appendString:city];
                }
                NSString *subLoc = placemark.subLocality;
                if (subLoc) {
                    [locAdress appendString:subLoc];
                }
                
                LOG_INFO("gpsChange", @"%@,%f,%f", locAdress, loc.coordinate.latitude, loc.coordinate.longitude);
                [self.locMgr stopUpdatingLocation];
            }else{
                LOG_INFO("gpsChange", @"获取定位城市失败");
            }
        }
    }];
}

- (CLLocationManager *)locMgr{
    if (!_locMgr) {
        _locMgr = [[CLLocationManager alloc] init];
    }
    return _locMgr;
}

- (NSString *)gxb_deviceUUID {
    CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuid = (NSString *)CFBridgingRelease(CFUUIDCreateString (kCFAllocatorDefault,uuidRef));
    
    uuid =  [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return uuid;
}

- (NSString *)gxb_deviceModel {
    return [UIDevice currentDevice].model;
}

- (NSString *)gxb_deviceName {
    return @"ios";
}

- (NSString *)gxb_deviceSystemVersion {
    return [UIDevice currentDevice].systemVersion;
}

- (NSString *)gxb_deviceAppVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

- (NSString *)gxb_deviceIPAdress {
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
