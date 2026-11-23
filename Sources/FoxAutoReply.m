#import "FoxAutoReply.h"
#import "FoxBridge.h"
#import "FoxStore.h"
#import "FoxModels.h"
#import <objc/runtime.h>

@interface FoxAutoReply ()
+ (void)processMessage:(id)message;
@end

static IMP gOriginalRecv = NULL;
static NSMutableDictionary<NSString *, NSDate *> *gCooldowns;

static id FoxValue(id obj, NSString *key) {
    @try {
        return [obj valueForKey:key];
    } @catch (__unused NSException *e) {
        return nil;
    }
}

static void FoxHandleRecv(id self, SEL _cmd, id message) {
    if (gOriginalRecv) {
        ((void (*)(id, SEL, id))gOriginalRecv)(self, _cmd, message);
    }
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            [FoxAutoReply processMessage:message];
        });
    }
}

@implementation FoxAutoReply

+ (void)installHook {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCooldowns = [NSMutableDictionary dictionary];
        Class cls = FoxFindClassBySuffix(@"IMListenerManager");
        if (!cls) {
            NSLog(@"[FoxAssistant] 未找到 IMListenerManager，自动回复未挂载");
            return;
        }

        SEL sel = NSSelectorFromString(@"handleOnRecvNewMessage:");
        Method method = class_getInstanceMethod(cls, sel);
        if (!method) {
            sel = NSSelectorFromString(@"onRecvNewMessage:");
            method = class_getInstanceMethod(cls, sel);
        }
        if (!method) {
            NSLog(@"[FoxAssistant] 未找到收消息回调，自动回复未挂载");
            return;
        }

        gOriginalRecv = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        class_replaceMethod(cls, sel, (IMP)FoxHandleRecv, types);
        NSLog(@"[FoxAssistant] 自动回复 hook: %@ - %@", NSStringFromClass(cls), NSStringFromSelector(sel));
    });
}

+ (void)processMessage:(id)message {
    if (!message || ![FoxStore shared].enabled) return;

    BOOL isSelf = [[FoxValue(message, @"isSelf") description] boolValue];
    if (isSelf) return;

    NSString *userID = FoxValue(message, @"userID");
    NSString *groupID = FoxValue(message, @"groupID");
    if (![userID isKindOfClass:[NSString class]] || !userID.length) return;

    id elem = FoxValue(message, @"textElem");
    NSString *text = elem ? FoxValue(elem, @"text") : nil;
    if (![text isKindOfClass:[NSString class]] || !text.length) return;

    NSString *nick = FoxValue(message, @"nickName");
    if ([nick isKindOfClass:[NSString class]] && [nick containsString:@"狐狸助手"]) return;

    NSDate *last = gCooldowns[userID];
    if (last && [[NSDate date] timeIntervalSinceDate:last] < 5.0) return;

    NSArray<FoxReplyRule *> *rules = [[FoxStore shared] rules];
    for (FoxReplyRule *rule in rules) {
        if (!rule.enabled || !rule.reply.length) continue;
        BOOL match = !rule.keyword.length;
        if (!match) {
            NSRange range = [text rangeOfString:rule.keyword options:NSCaseInsensitiveSearch];
            match = range.location != NSNotFound;
        }
        if (!match) continue;

        gCooldowns[userID] = [NSDate date];
        NSLog(@"[FoxAssistant] 自动回复 -> %@ (%@)", userID, groupID.length ? groupID : @"私聊");
        [FoxBridge sendText:rule.reply toUser:userID group:nil completion:^(BOOL ok, NSError *error) {
            if (!ok) NSLog(@"[FoxAssistant] 自动回复失败: %@", error.localizedDescription);
        }];
        break;
    }
}

@end
