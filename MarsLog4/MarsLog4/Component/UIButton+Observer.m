//
//  UIButton+Observer.m
//  iOSDemoXlog
//
//  Created by zhudong on 2017/7/13.
//
//

#import "UIButton+Observer.h"
#import <objc/runtime.h>
#import "LogUtil.h"

@implementation UIButton (Observer)

+ (void)load{

    
    Method originalPoint = class_getInstanceMethod([self class], @selector(sendAction: to: forEvent:));
    Method currentPoint = class_getInstanceMethod([self class], @selector(observer_sendAction: to: forEvent:));
    
    
    if ([NSStringFromClass(self) isEqualToString: @"UIButton"]) {
        method_exchangeImplementations(originalPoint, currentPoint);
    }
    [super load];
    
}
- (void)observer_sendAction:(SEL)action to:(nullable id)target forEvent:(nullable UIEvent *)event{
    
    if ([self isKindOfClass:[UIButton class]] && self.titleLabel.text.length > 0 ) {
        LOG_INFO("click", @"%@", self.titleLabel.text);
    }
    if ([self respondsToSelector:@selector(observer_sendAction: to: forEvent:)]) {
        return  [self observer_sendAction:action to:target forEvent:event];
    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-W-PerformSelector"
        [target performSelector:action];
#pragma clang diagnostic pop
    }
}

//    Method originalPoint = class_getInstanceMethod([self class], @selector(hitTest: withEvent:));
//    Method currentPoint = class_getInstanceMethod([self class], @selector(observer_hitTest: withEvent:));
//    method_exchangeImplementations(originalPoint, currentPoint);

//- (nullable UIView *)observer_hitTest:(CGPoint)point withEvent:(nullable UIEvent *) event {
//   
//    CGPoint newP = [self convertPoint:point toView:self];
//    
//    if ([self pointInside:newP withEvent:event]) {
//        if (self.titleLabel.text.length > 0) {
//            LOG_INFO("Button", @"%@,%@", self.titleLabel.text, NSStringFromCGPoint(point));
//        }else{
//            LOG_INFO("Button", @"%@,%@", @"no title", NSStringFromCGPoint(point));
//        }
//    }
//    return  [self observer_hitTest:point withEvent:event];
//    
//}
@end
