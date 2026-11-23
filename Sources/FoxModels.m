#import "FoxModels.h"

@implementation FoxGroup
@end

@implementation FoxMember
@end

@implementation FoxMomentTask

- (NSDictionary *)dictionary {
    return @{
        @"id": self.taskID ?: @"",
        @"text": self.text ?: @"",
        @"fireDate": @([self.fireDate timeIntervalSince1970]),
        @"repeatDaily": @(self.repeatDaily),
        @"enabled": @(self.enabled),
        @"lastRun": @(self.lastRun),
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    FoxMomentTask *t = [FoxMomentTask new];
    t.taskID = dict[@"id"] ?: [[NSUUID UUID] UUIDString];
    t.text = dict[@"text"] ?: @"";
    t.fireDate = [NSDate dateWithTimeIntervalSince1970:[dict[@"fireDate"] doubleValue]];
    t.repeatDaily = [dict[@"repeatDaily"] boolValue];
    t.enabled = dict[@"enabled"] ? [dict[@"enabled"] boolValue] : YES;
    t.lastRun = [dict[@"lastRun"] doubleValue];
    return t;
}

@end

@implementation FoxReplyRule

- (NSDictionary *)dictionary {
    return @{
        @"keyword": self.keyword ?: @"",
        @"reply": self.reply ?: @"",
        @"enabled": @(self.enabled),
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    FoxReplyRule *r = [FoxReplyRule new];
    r.keyword = dict[@"keyword"] ?: @"";
    r.reply = dict[@"reply"] ?: @"";
    r.enabled = dict[@"enabled"] ? [dict[@"enabled"] boolValue] : YES;
    return r;
}

@end
