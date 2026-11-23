#import "FoxScheduler.h"
#import "FoxStore.h"
#import "FoxBridge.h"
#import <UIKit/UIKit.h>

@implementation FoxScheduler {
    NSTimer *_timer;
    BOOL _publishing;
}

+ (instancetype)shared {
    static FoxScheduler *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [FoxScheduler new]; });
    return s;
}

- (void)start {
    if (_timer) return;
    _timer = [NSTimer timerWithTimeInterval:20.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [self checkNow];
}

- (void)appDidBecomeActive {
    [self checkNow];
}

- (void)tick {
    [self checkNow];
}

- (void)checkNow {
    if (_publishing) return;
    if (![FoxStore shared].enabled) return;

    NSArray<FoxMomentTask *> *tasks = [[FoxStore shared] tasks];
    NSDate *now = [NSDate date];
    for (FoxMomentTask *task in tasks) {
        if (!task.enabled || !task.text.length) continue;
        if (!task.fireDate) task.fireDate = now;
        if ([task.fireDate timeIntervalSinceDate:now] > 0) continue;
        if (now.timeIntervalSince1970 - task.lastRun < 60) continue;

        _publishing = YES;
        task.lastRun = now.timeIntervalSince1970;

        NSMutableArray *updated = [tasks mutableCopy];
        NSUInteger idx = [updated indexOfObject:task];
        if (idx != NSNotFound) updated[idx] = task;

        if (task.repeatDaily) {
            NSDate *next = task.fireDate ?: now;
            while ([next timeIntervalSinceDate:now] <= 0) {
                next = [next dateByAddingTimeInterval:86400];
            }
            task.fireDate = next;
        } else {
            task.enabled = NO;
        }
        [[FoxStore shared] saveTasks:updated];

        __weak typeof(self) weakSelf = self;
        [FoxBridge publishMoment:task.text completion:^(BOOL ok, NSError *error) {
            if (!ok) NSLog(@"[FoxAssistant] 定时动态失败: %@", error.localizedDescription);
            else NSLog(@"[FoxAssistant] 定时动态已发布");
            FoxScheduler *strongSelf = weakSelf;
            if (strongSelf) strongSelf->_publishing = NO;
        }];
        break; // 一次只处理一条，避免连续弹出发布页
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate];
}

@end
