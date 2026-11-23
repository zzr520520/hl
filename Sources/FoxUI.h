#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FoxUI : NSObject

+ (void)presentAssistant;
+ (void)dismissAssistant;
+ (BOOL)isAssistantVisible;

/// 在设置页的“商城”Cell 下方插入“狐狸助手”入口；找不到时回退到 tableFooter。
+ (void)installSettingsEntryInViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
