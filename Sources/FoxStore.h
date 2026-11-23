#import <Foundation/Foundation.h>
#import "FoxModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface FoxStore : NSObject

@property (nonatomic, assign) BOOL enabled;

+ (instancetype)shared;

- (NSArray<FoxMomentTask *> *)tasks;
- (void)saveTasks:(NSArray<FoxMomentTask *> *)tasks;

- (NSArray<FoxReplyRule *> *)rules;
- (void)saveRules:(NSArray<FoxReplyRule *> *)rules;

@end

NS_ASSUME_NONNULL_END
