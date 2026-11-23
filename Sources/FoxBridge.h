#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FoxModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface FoxBridge : NSObject

+ (BOOL)isTIMAvailable;

/// 当前打开的群 ID（从 ChatGroupViewController / GroupDetailViewController 读取）
+ (nullable NSString *)currentGroupID;

/// 拉取我加入的群
+ (void)fetchJoinedGroups:(void (^)(NSArray<FoxGroup *> *groups, NSError * _Nullable error))completion;

/// 拉取指定群的全部成员（自动翻页）
+ (void)fetchMembersOfGroup:(NSString *)groupID
                 completion:(void (^)(NSArray<FoxMember *> *members, NSError * _Nullable error))completion;

/// 发送文本。groupID 为空 = 私聊；groupID 非空 = 群聊。
+ (void)sendText:(NSString *)text
           toUser:(nullable NSString *)userID
            group:(nullable NSString *)groupID
       completion:(void (^)(BOOL ok, NSError * _Nullable error))completion;

/// 定时动态：通过 App 自带的动态发布页完成（需要 App 在前台）
+ (void)publishMoment:(NSString *)text
             completion:(void (^)(BOOL ok, NSError * _Nullable error))completion;

@end

/// 按类名后缀查找 Swift/ObjC 类（兼容 _TtC7skychatXXX 前缀）
Class _Nullable FoxFindClassBySuffix(NSString *suffix);

/// 当前最顶层可 present 的控制器
UIViewController * _Nullable FoxTopViewController(void);

/// 递归找 UITextView / UIButton
UIView * _Nullable FoxFindView(UIView *root, BOOL (^predicate)(UIView *view));
UIButton * _Nullable FoxFindButton(UIView *root, NSString *titlePart);
UILabel * _Nullable FoxFindLabel(UIView *root, NSString *textPart);

NS_ASSUME_NONNULL_END
