#import "FoxBridge.h"
#import <objc/message.h>
#import <objc/runtime.h>

typedef void (^FoxTIMFail)(int code, NSString *desc);
typedef void (^FoxTIMSucc)(void);
typedef void (^FoxGroupListSucc)(NSArray *groups);
typedef void (^FoxMemberListSucc)(NSArray *members, uint64_t nextSeq, BOOL isFinished);

static NSError *FoxMakeError(NSString *msg) {
    return [NSError errorWithDomain:@"FoxAssistant" code:-1 userInfo:@{NSLocalizedDescriptionKey: msg ?: @"未知错误"}];
}

Class FoxFindClassBySuffix(NSString *suffix) {
    if (!suffix.length) return Nil;
    Class direct = NSClassFromString(suffix);
    if (direct) return direct;

    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return Nil;
    Class *classes = (Class *)malloc(sizeof(Class) * count);
    if (!classes) return Nil;
    count = objc_getClassList(classes, count);
    Class found = Nil;
    for (int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if ([name hasSuffix:suffix] || [name hasSuffix:[@"." stringByAppendingString:suffix]]) {
            found = classes[i];
            break;
        }
    }
    free(classes);
    return found;
}

static UIWindow *FoxKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) return w;
            }
        }
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    UIWindow *key = UIApplication.sharedApplication.keyWindow;
    if (key) return key;
    return UIApplication.sharedApplication.windows.firstObject;
}

UIViewController *FoxTopViewController(void) {
    UIWindow *window = FoxKeyWindow();
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:[UINavigationController class]]) {
        vc = ((UINavigationController *)vc).topViewController ?: vc;
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        vc = ((UITabBarController *)vc).selectedViewController ?: vc;
    }
    if ([vc isKindOfClass:[UIAlertController class]] && vc.presentingViewController) {
        vc = vc.presentingViewController;
    }
    return vc;
}

UIView *FoxFindView(UIView *root, BOOL (^predicate)(UIView *view)) {
    if (!root) return nil;
    if (predicate && predicate(root)) return root;
    for (UIView *sub in root.subviews) {
        UIView *hit = FoxFindView(sub, predicate);
        if (hit) return hit;
    }
    return nil;
}

UIButton *FoxFindButton(UIView *root, NSString *titlePart) {
    return (UIButton *)FoxFindView(root, ^BOOL(UIView *v) {
        if (![v isKindOfClass:[UIButton class]]) return NO;
        UIButton *b = (UIButton *)v;
        NSString *t = [b titleForState:UIControlStateNormal] ?: b.currentTitle ?: @"";
        return [t containsString:titlePart];
    });
}

UILabel *FoxFindLabel(UIView *root, NSString *textPart) {
    return (UILabel *)FoxFindView(root, ^BOOL(UIView *v) {
        if (![v isKindOfClass:[UILabel class]]) return NO;
        NSString *t = ((UILabel *)v).text ?: @"";
        return [t containsString:textPart];
    });
}

static id FoxTIMManager(void) {
    Class cls = NSClassFromString(@"V2TIMManager");
    if (!cls) return nil;
    SEL sel = @selector(sharedInstance);
    if (![cls respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(cls, sel);
}

static id FoxValue(id obj, NSString *key) {
    if (!obj || !key.length) return nil;
    @try {
        id v = [obj valueForKey:key];
        return v;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

@implementation FoxBridge

+ (BOOL)isTIMAvailable {
    return FoxTIMManager() != nil;
}

+ (NSString *)currentGroupID {
    UIViewController *top = FoxTopViewController();
    NSMutableArray *stack = [NSMutableArray array];
    if (top) [stack addObject:top];
    if (top.navigationController) [stack addObjectsFromArray:top.navigationController.viewControllers];
    if (top.presentingViewController.navigationController) {
        [stack addObjectsFromArray:top.presentingViewController.navigationController.viewControllers];
    }

    NSArray *keys = @[
        @"groupID", @"groupId",
        @"groupInfo.groupID", @"groupInfo.groupId",
        @"groupInfoModel.groupId", @"groupInfoModel.groupID",
        @"groupModel.groupId", @"model.groupId",
        @"conversation.groupID", @"chatModel.groupId",
    ];
    for (UIViewController *vc in stack.reverseObjectEnumerator) {
        NSString *cls = NSStringFromClass([vc class]);
        if (![cls containsString:@"Group"] && ![cls containsString:@"Chat"]) continue;
        for (NSString *key in keys) {
            id v = FoxValue(vc, key);
            if ([v isKindOfClass:[NSString class]] && [v length] > 0) return v;
            if ([v respondsToSelector:@selector(stringValue)]) {
                NSString *s = [v stringValue];
                if (s.length) return s;
            }
        }
    }
    return nil;
}

+ (void)fetchJoinedGroups:(void (^)(NSArray<FoxGroup *> *, NSError *))completion {
    id mgr = FoxTIMManager();
    if (!mgr) {
        if (completion) completion(@[], FoxMakeError(@"当前环境未加载腾讯 IM"));
        return;
    }
    SEL sel = @selector(getJoinedGroupList:fail:);
    if (![mgr respondsToSelector:sel]) {
        if (completion) completion(@[], FoxMakeError(@"IM 不支持 getJoinedGroupList"));
        return;
    }

    FoxGroupListSucc succ = ^(NSArray *groups) {
        NSMutableArray *out = [NSMutableArray array];
        for (id g in groups) {
            NSString *gid = FoxValue(g, @"groupID");
            NSString *name = FoxValue(g, @"groupName");
            if (!gid.length) continue;
            FoxGroup *fg = [FoxGroup new];
            fg.groupID = gid;
            fg.name = name.length ? name : gid;
            [out addObject:fg];
        }
        [out sortUsingComparator:^NSComparisonResult(FoxGroup *a, FoxGroup *b) {
            return [a.name localizedCompare:b.name];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(out, nil);
        });
    };
    FoxTIMFail fail = ^(int code, NSString *desc) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(@[], FoxMakeError(desc ?: [NSString stringWithFormat:@"IM 错误 %d", code]));
        });
    };
    ((void (*)(id, SEL, id, id))objc_msgSend)(mgr, sel, succ, fail);
}

+ (void)fetchMembersOfGroup:(NSString *)groupID completion:(void (^)(NSArray<FoxMember *> *, NSError *))completion {
    if (!groupID.length) {
        if (completion) completion(@[], FoxMakeError(@"群 ID 为空"));
        return;
    }
    id mgr = FoxTIMManager();
    if (!mgr) {
        if (completion) completion(@[], FoxMakeError(@"当前环境未加载腾讯 IM"));
        return;
    }
    SEL sel = @selector(getGroupMemberList:filter:nextSeq:succ:fail:);
    if (![mgr respondsToSelector:sel]) {
        if (completion) completion(@[], FoxMakeError(@"IM 不支持 getGroupMemberList"));
        return;
    }

    __block NSMutableArray *all = [NSMutableArray array];
    __block BOOL finished = NO;
    __block void (^fetchPage)(uint64_t);

    FoxTIMFail fail = ^(int code, NSString *desc) {
        if (finished) return;
        finished = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(all, FoxMakeError(desc ?: [NSString stringWithFormat:@"IM 错误 %d", code]));
        });
    };

    fetchPage = ^(uint64_t seq) {
        FoxMemberListSucc succ = ^(NSArray *members, uint64_t nextSeq, BOOL isFinished) {
            for (id m in members) {
                NSString *uid = FoxValue(m, @"userID");
                NSString *nick = FoxValue(m, @"nickName");
                NSString *card = FoxValue(m, @"nameCard");
                NSString *remark = FoxValue(m, @"friendRemark");
                if (!uid.length) continue;
                FoxMember *fm = [FoxMember new];
                fm.userID = uid;
                fm.name = card.length ? card : (remark.length ? remark : (nick.length ? nick : uid));
                [all addObject:fm];
            }
            if (isFinished || nextSeq == 0 || nextSeq == seq) {
                if (finished) return;
                finished = YES;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(all, nil);
                });
                return;
            }
            fetchPage(nextSeq);
        };
        ((void (*)(id, SEL, id, uint32_t, uint64_t, id, id))objc_msgSend)(
            mgr, sel, groupID, (uint32_t)0, seq, succ, fail);
    };
    fetchPage(0);
}

+ (void)sendText:(NSString *)text
           toUser:(NSString *)userID
            group:(NSString *)groupID
       completion:(void (^)(BOOL, NSError *))completion {
    if (!text.length) {
        if (completion) completion(NO, FoxMakeError(@"消息为空"));
        return;
    }
    if (!userID.length && !groupID.length) {
        if (completion) completion(NO, FoxMakeError(@"缺少接收方"));
        return;
    }
    id mgr = FoxTIMManager();
    if (!mgr) {
        if (completion) completion(NO, FoxMakeError(@"当前环境未加载腾讯 IM"));
        return;
    }
    SEL createSel = @selector(createTextMessage:);
    SEL sendSel = @selector(sendMessage:receiver:groupID:priority:onlineUserOnly:offlinePushInfo:progress:succ:fail:);
    if (![mgr respondsToSelector:createSel] || ![mgr respondsToSelector:sendSel]) {
        if (completion) completion(NO, FoxMakeError(@"IM 不支持文本发送"));
        return;
    }

    id msg = ((id (*)(id, SEL, id))objc_msgSend)(mgr, createSel, text);
    if (!msg) {
        if (completion) completion(NO, FoxMakeError(@"创建消息失败"));
        return;
    }

    FoxTIMSucc succ = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(YES, nil);
        });
    };
    FoxTIMFail fail = ^(int code, NSString *desc) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, FoxMakeError(desc ?: [NSString stringWithFormat:@"IM 错误 %d", code]));
        });
    };

    ((void (*)(id, SEL, id, id, id, NSInteger, BOOL, id, id, id, id))objc_msgSend)(
        mgr, sendSel, msg,
        userID ?: @"",
        groupID ?: @"",
        (NSInteger)0,
        (BOOL)NO,
        nil,
        nil,
        succ,
        fail);
}

+ (void)publishMoment:(NSString *)text completion:(void (^)(BOOL, NSError *))completion {
    if (!text.length) {
        if (completion) completion(NO, FoxMakeError(@"动态内容为空"));
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = FoxFindClassBySuffix(@"SkyMomentPublishViewController");
        if (!cls) {
            if (completion) completion(NO, FoxMakeError(@"未找到动态发布页"));
            return;
        }

        UIViewController *publishVC = nil;
        @try {
            publishVC = [[cls alloc] init];
        } @catch (__unused NSException *e) {
            publishVC = nil;
        }
        if (!publishVC) {
            @try {
                publishVC = [[cls alloc] initWithNibName:nil bundle:nil];
            } @catch (__unused NSException *e) {
                publishVC = nil;
            }
        }
        if (!publishVC) {
            if (completion) completion(NO, FoxMakeError(@"动态发布页初始化失败"));
            return;
        }

        UIViewController *top = FoxTopViewController();
        if (!top) {
            if (completion) completion(NO, FoxMakeError(@"没有可用的顶层控制器"));
            return;
        }

        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:publishVC];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [top presentViewController:nav animated:YES completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UITextView *tv = (UITextView *)FoxFindView(publishVC.view, ^BOOL(UIView *v) {
                    return [v isKindOfClass:[UITextView class]];
                });
                if (tv) {
                    tv.text = text;
                    @try {
                        if ([tv.delegate respondsToSelector:@selector(textViewDidChange:)]) {
                            [tv.delegate textViewDidChange:tv];
                        }
                    } @catch (__unused NSException *e) {}
                    [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:tv];
                }

                UIButton *btn = FoxFindButton(publishVC.view, @"发布");
                if (!btn) btn = FoxFindButton(publishVC.view, @"发送");
                UIBarButtonItem *barItem = publishVC.navigationItem.rightBarButtonItem;
                NSString *barTitle = barItem.title ?: @"";
                BOOL tapped = NO;

                if ([barTitle containsString:@"发布"] || [barTitle containsString:@"发送"]) {
                    @try {
                        if (barItem.target && barItem.action) {
                            ((void (*)(id, SEL, id))objc_msgSend)(barItem.target, barItem.action, barItem);
                            tapped = YES;
                        }
                    } @catch (__unused NSException *e) {}
                }
                if (!tapped && btn) {
                    [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
                    tapped = YES;
                }

                if (completion) {
                    if (tapped) completion(YES, nil);
                    else completion(NO, FoxMakeError(@"未找到发布按钮"));
                }
            });
        }];
    });
}

@end
