#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FoxScheduler : NSObject

+ (instancetype)shared;
- (void)start;
- (void)checkNow;

@end

NS_ASSUME_NONNULL_END
