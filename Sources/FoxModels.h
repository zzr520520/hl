#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FoxGroup : NSObject
@property (nonatomic, copy) NSString *groupID;
@property (nonatomic, copy) NSString *name;
@end

@interface FoxMember : NSObject
@property (nonatomic, copy) NSString *userID;
@property (nonatomic, copy) NSString *name;
@end

@interface FoxMomentTask : NSObject
@property (nonatomic, copy) NSString *taskID;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSDate *fireDate;
@property (nonatomic, assign) BOOL repeatDaily;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSTimeInterval lastRun;
- (NSDictionary *)dictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
@end

@interface FoxReplyRule : NSObject
@property (nonatomic, copy) NSString *keyword; // 空字符串 = 全部消息
@property (nonatomic, copy) NSString *reply;
@property (nonatomic, assign) BOOL enabled;
- (NSDictionary *)dictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
