//
//  JJXlog.h
//  iOSDemoXlog
//
//  Created by zhudong on 2017/7/25.
//
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface JJXlog : NSObject

+ (instancetype)shareXLog;
//默认文件名为uuid
- (void)setLoginName:(NSString *)name;
//设置获取app关键字
- (void)setKeyWords:(NSArray *)keys;
- (void)start;
- (void)stop;
//生成xlog文件
- (void)flush;
- (void)upload;
//以秒计时
- (void)setTimeInterval:(int)time;
- (void)cancelTime;
//打开定位
- (void)openLocation;
//重新请求点位授权
- (void)requestLocation;

@end
