#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 一个可注册的功能项。
/// key 为空表示“动作项”，点击立即执行 handler；
/// key 非空表示“开关项”，开关状态保存在 NSUserDefaults。
@interface FoxFeatureItem : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *key;
@property (nonatomic, assign) BOOL toggle;
@property (nonatomic, copy, nullable) void (^handler)(void);

+ (instancetype)itemWithTitle:(NSString *)title
                          key:(nullable NSString *)key
                       toggle:(BOOL)toggle
                      handler:(nullable void (^)(void))handler;

@end

/// 功能注册表。你在 FoxRegisterDefaults() 里追加 item 即可扩展面板。
@interface FoxFeatureRegistry : NSObject

@property (nonatomic, strong, readonly) NSMutableArray<FoxFeatureItem *> *items;

+ (instancetype)shared;
- (void)addItem:(FoxFeatureItem *)item;

@end

NS_ASSUME_NONNULL_END
