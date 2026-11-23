#import "FoxAssistant.h"
#import "FoxUI.h"
#import "FoxScheduler.h"
#import "FoxAutoReply.h"
#import "FoxBridge.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalViewDidAppear = NULL;
static char kFoxGestureKey;

static BOOL FoxIsSettingsClass(NSString *name) {
    if (!name.length) return NO;
    NSArray *parts = @[@"SetUp", @"Setting", @"UserCenter", @"Account", @"LoginSetUp"];
    for (NSString *p in parts) {
        if ([name containsString:p]) return YES;
    }
    return NO;
}

static UIWindow *FoxAssistantKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in ws.windows) if (w.isKeyWindow) return w;
        }
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) return w;
        }
    }
    UIWindow *key = UIApplication.sharedApplication.keyWindow;
    if (key) return key;
    return UIApplication.sharedApplication.windows.firstObject;
}

static void FoxViewDidAppearHook(id self, SEL _cmd, BOOL animated) {
    if (gOriginalViewDidAppear) {
        ((void (*)(id, SEL, BOOL))gOriginalViewDidAppear)(self, _cmd, animated);
    }
    if (![self isKindOfClass:[UIViewController class]]) return;
    NSString *cls = NSStringFromClass([self class]);
    if (!FoxIsSettingsClass(cls)) return;
    __weak UIViewController *weakVC = (UIViewController *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [FoxUI installSettingsEntryInViewController:weakVC];
    });
}

@implementation FoxAssistant

+ (void)start {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self installViewDidAppearHook];
            [[FoxScheduler shared] start];
            [self installGesture];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(appDidBecomeActive)
                                                         name:UIApplicationDidBecomeActiveNotification
                                                       object:nil];

            // IM 类可能还没完成注册，延迟挂 hook。
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [FoxAutoReply installHook];
            });

            // dylib 注入时如果已经停在设置页，补一次入口。
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIViewController *top = FoxTopViewController();
                if (top && FoxIsSettingsClass(NSStringFromClass([top class]))) {
                    [FoxUI installSettingsEntryInViewController:top];
                }
            });
        });
    });
}

+ (void)appDidBecomeActive {
    [self installGesture];
}

+ (void)installViewDidAppearHook {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method method = class_getInstanceMethod([UIViewController class], @selector(viewDidAppear:));
        if (!method) return;
        gOriginalViewDidAppear = method_getImplementation(method);
        class_replaceMethod([UIViewController class],
                            @selector(viewDidAppear:),
                            (IMP)FoxViewDidAppearHook,
                            method_getTypeEncoding(method));
    });
}

+ (void)installGesture {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = FoxAssistantKeyWindow();
        if (!window) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self installGesture];
            });
            return;
        }
        for (UIGestureRecognizer *g in window.gestureRecognizers) {
            if (objc_getAssociatedObject(g, &kFoxGestureKey)) return;
        }

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerDoubleTap:)];
        tap.numberOfTouchesRequired = 2;
        tap.numberOfTapsRequired = 2;
        tap.cancelsTouchesInView = NO;
        tap.delaysTouchesBegan = NO;
        objc_setAssociatedObject(tap, &kFoxGestureKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [window addGestureRecognizer:tap];
        NSLog(@"[FoxAssistant] 双指双击手势已安装");
    });
}

+ (void)handleTwoFingerDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    if ([FoxUI isAssistantVisible]) [FoxUI dismissAssistant];
    else [FoxUI presentAssistant];
}

@end

__attribute__((constructor))
static void FoxAssistantConstructor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [FoxAssistant start];
    });
}
