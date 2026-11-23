#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 插件入口：hook 自动回复、启动定时器、安装设置页入口和双指双击手势。
@interface FoxAssistant : NSObject
+ (void)start;
@end

NS_ASSUME_NONNULL_END
