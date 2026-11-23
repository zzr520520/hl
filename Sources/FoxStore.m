#import "FoxStore.h"

static NSString *const kSuite = @"com.feiouxun.foxmeta.foxassistant";
static NSString *const kTasksKey = @"momentTasks";
static NSString *const kRulesKey = @"replyRules";
static NSString *const kEnabledKey = @"enabled";

@implementation FoxStore

+ (instancetype)shared {
    static FoxStore *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [FoxStore new]; });
    return s;
}

- (NSUserDefaults *)defaults {
    return [[NSUserDefaults alloc] initWithSuiteName:kSuite];
}

- (BOOL)enabled {
    id v = [self.defaults objectForKey:kEnabledKey];
    return v ? [v boolValue] : YES;
}

- (void)setEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:kEnabledKey];
    [self.defaults synchronize];
}

- (NSArray<FoxMomentTask *> *)tasks {
    NSArray *raw = [self.defaults arrayForKey:kTasksKey];
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *d in raw) {
        if ([d isKindOfClass:[NSDictionary class]]) [out addObject:[FoxMomentTask fromDictionary:d]];
    }
    return out;
}

- (void)saveTasks:(NSArray<FoxMomentTask *> *)tasks {
    NSMutableArray *raw = [NSMutableArray array];
    for (FoxMomentTask *t in tasks) [raw addObject:[t dictionary]];
    [self.defaults setObject:raw forKey:kTasksKey];
    [self.defaults synchronize];
}

- (NSArray<FoxReplyRule *> *)rules {
    NSArray *raw = [self.defaults arrayForKey:kRulesKey];
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *d in raw) {
        if ([d isKindOfClass:[NSDictionary class]]) [out addObject:[FoxReplyRule fromDictionary:d]];
    }
    return out;
}

- (void)saveRules:(NSArray<FoxReplyRule *> *)rules {
    NSMutableArray *raw = [NSMutableArray array];
    for (FoxReplyRule *r in rules) [raw addObject:[r dictionary]];
    [self.defaults setObject:raw forKey:kRulesKey];
    [self.defaults synchronize];
}

@end
