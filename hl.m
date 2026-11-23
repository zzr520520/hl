// hl.dylib 骨架：让工作流开箱就能编译通过
// 后续把源码放进来（*.m / *.c），工作流会自动把它们全部编进 hl.dylib
#import <Foundation/Foundation.h>

__attribute__((constructor))
static void hl_entry(void) {
    NSLog(@"[hl] dylib loaded");
}
