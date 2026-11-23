#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FoxModels.h"
#import "FoxBridge.h"
#import "FoxStore.h"
#import "FoxScheduler.h"
#import "FoxUI.h"

@class FoxAssistantViewController, FoxMemberPickerViewController, FoxMomentListViewController, FoxAutoReplyViewController, FoxGroupForwardViewController, FoxMomentEditorViewController;

static UIColor *FoxAccent(void) {
    return [UIColor colorWithRed:0.93 green:0.69 blue:0.20 alpha:1.0];
}

static UIColor *FoxGroupedBackground(void) {
    if (@available(iOS 13.0, *)) return [UIColor systemGroupedBackgroundColor];
    return [UIColor colorWithWhite:0.95 alpha:1.0];
}

static UIColor *FoxCardBackground(void) {
    if (@available(iOS 13.0, *)) return [UIColor secondarySystemGroupedBackgroundColor];
    return [UIColor whiteColor];
}

static UIColor *FoxTextColor(void) {
    if (@available(iOS 13.0, *)) return [UIColor labelColor];
    return [UIColor blackColor];
}

static UIColor *FoxSecondaryTextColor(void) {
    if (@available(iOS 13.0, *)) return [UIColor secondaryLabelColor];
    return [UIColor grayColor];
}

static UILabel *FoxMakeLabel(NSString *text, CGFloat size, BOOL bold, UIColor *color) {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.text = text;
    l.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    l.textColor = color;
    l.numberOfLines = 0;
    return l;
}

static void FoxShowAlert(UIViewController *vc, NSString *title, NSString *message) {
    if (!vc) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

static NSString *FoxShortText(NSString *text, NSUInteger maxLen) {
    if (text.length <= maxLen) return text ?: @"";
    return [[text substringToIndex:maxLen] stringByAppendingString:@"…"];
}

static NSString *FoxDateText(NSDate *date) {
    static NSDateFormatter *fmt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [NSDateFormatter new];
        fmt.dateFormat = @"MM-dd HH:mm";
    });
    return [fmt stringFromDate:date ?: [NSDate date]];
}

static UINavigationController *FoxWrapInNav(UIViewController *vc) {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    return nav;
}
