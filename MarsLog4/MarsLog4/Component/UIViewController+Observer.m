//
//  UIViewController+Observer.m
//  iOSDemoXlog
//
//  Created by zhudong on 2017/7/12.
//
//

#import "UIViewController+Observer.h"
#import <objc/runtime.h>
#import "LogUtil.h"
#import "LogHelper.h"

@implementation UIViewController (Observer)

+ (void)load{
    Method originalAppear = class_getInstanceMethod([self class], @selector(viewWillAppear:));
    Method currentAppear = class_getInstanceMethod([self class], @selector(pagerIn:));
    method_exchangeImplementations(originalAppear, currentAppear);
    
    Method originalDisappear = class_getInstanceMethod([self class], @selector(viewWillDisappear:));
    Method currentDisappear = class_getInstanceMethod([self class], @selector(pagerOut:));
    method_exchangeImplementations(originalDisappear, currentDisappear);
    
    
}

- (void)pagerIn:(BOOL)animated{
    
    if (self.title.length > 0) {
        NSString *className = NSStringFromClass([self class]);
        const char *funName = [className cStringUsingEncoding:NSUTF8StringEncoding];
        [LogHelper logWithLevel:kLevelInfo moduleName:"pageIn" fileName:__FILENAME__ lineNumber:__LINE__ funcName:funName message:self.title];
    }
    
    [self pagerIn:animated];
}

- (void)pagerOut:(BOOL)animated{
    
    if (self.title.length > 0) {
        NSString *className = NSStringFromClass([self class]);
        const char *funName = [className cStringUsingEncoding:NSUTF8StringEncoding];
        [LogHelper logWithLevel:kLevelInfo moduleName:"pageOut" fileName:__FILENAME__ lineNumber:__LINE__ funcName:funName message:self.title];
    }
    
    [self pagerOut:animated];
}
@end
