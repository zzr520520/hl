#import "FoxFeature.h"

@interface FoxFeatureRegistry ()
@property (nonatomic, strong, readwrite) NSMutableArray<FoxFeatureItem *> *items;
@end

@implementation FoxFeatureItem

+ (instancetype)itemWithTitle:(NSString *)title
                          key:(NSString *)key
                       toggle:(BOOL)toggle
                      handler:(void (^)(void))handler {
    FoxFeatureItem *item = [FoxFeatureItem new];
    item.title = title;
    item.key = key;
    item.toggle = toggle;
    item.handler = handler;
    return item;
}

@end

@implementation FoxFeatureRegistry

+ (instancetype)shared {
    static FoxFeatureRegistry *registry;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        registry = [FoxFeatureRegistry new];
        registry.items = [NSMutableArray array];
    });
    return registry;
}

- (void)addItem:(FoxFeatureItem *)item {
    if (item) [self.items addObject:item];
}

@end
