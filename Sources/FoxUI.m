#import "FoxUIShared.h"

#pragma mark - Group forward

@interface FoxGroupForwardViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<FoxGroup *> *groups;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedIDs;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIButton *forwardButton;
@end

@implementation FoxGroupForwardViewController

- (instancetype)init {
    self = [super init];
    if (self) _selectedIDs = [NSMutableSet set];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"群转发";
    self.view.backgroundColor = FoxGroupedBackground();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:self action:@selector(closeTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addManualTapped)];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 58;
    _tableView.backgroundColor = FoxGroupedBackground();
    [self.view addSubview:_tableView];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 56)];
    UIButton *all = [UIButton buttonWithType:UIButtonTypeSystem];
    [all setTitle:@"全选" forState:UIControlStateNormal];
    all.titleLabel.font = [UIFont systemFontOfSize:13];
    all.tag = 301;
    [all addTarget:self action:@selector(selectAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:all];

    UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
    [clear setTitle:@"清除" forState:UIControlStateNormal];
    clear.titleLabel.font = [UIFont systemFontOfSize:13];
    clear.tag = 302;
    [clear addTarget:self action:@selector(clearTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:clear];

    _countLabel = FoxMakeLabel(@"已选 0 / 0", 12, NO, FoxSecondaryTextColor());
    _countLabel.textAlignment = NSTextAlignmentRight;
    [header addSubview:_countLabel];
    _tableView.tableHeaderView = header;

    UIView *bottom = [[UIView alloc] initWithFrame:CGRectZero];
    bottom.backgroundColor = FoxCardBackground();
    bottom.tag = 400;
    [self.view addSubview:bottom];

    _forwardButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _forwardButton.backgroundColor = FoxAccent();
    [_forwardButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _forwardButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    _forwardButton.layer.cornerRadius = 10;
    [_forwardButton setTitle:@"转发到选中群" forState:UIControlStateNormal];
    [_forwardButton addTarget:self action:@selector(forwardTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottom addSubview:_forwardButton];

    [self loadGroups];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    UIView *bottom = [self.view viewWithTag:400];
    CGFloat bottomH = 64;
    if (@available(iOS 11.0, *)) bottomH += self.view.safeAreaInsets.bottom;
    bottom.frame = CGRectMake(0, h - bottomH, w, bottomH);
    _tableView.frame = CGRectMake(0, 0, w, h - bottomH);
    _forwardButton.frame = CGRectMake(16, 9, w - 32, 46);

    UIView *header = _tableView.tableHeaderView;
    if (header) {
        header.frame = CGRectMake(0, 0, w, 56);
        UIButton *all = (UIButton *)[header viewWithTag:301];
        UIButton *clear = (UIButton *)[header viewWithTag:302];
        all.frame = CGRectMake(16, 12, 56, 32);
        clear.frame = CGRectMake(80, 12, 56, 32);
        _countLabel.frame = CGRectMake(150, 12, w - 166, 32);
    }
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadGroups {
    __weak typeof(self) weakSelf = self;
    [FoxBridge fetchJoinedGroups:^(NSArray<FoxGroup *> *groups, NSError *error) {
        if (!weakSelf) return;
        weakSelf.groups = groups;
        [weakSelf.tableView reloadData];
        [weakSelf updateCount];
        if (!groups.count) {
            FoxShowAlert(weakSelf, @"没有拿到群列表", @"可点右上角“+”手动添加群 ID，或先打开一个群聊再回来。");
        }
    }];
}

- (void)addManualTapped {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"手动添加群" message:@"输入 groupID，一行一个或用逗号分隔" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"groupID1, groupID2"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        NSString *raw = a.textFields.firstObject.text ?: @"";
        NSArray *parts = [raw componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",，;；\n "]];
        NSMutableArray *newGroups = [self.groups mutableCopy] ?: [NSMutableArray array];
        for (NSString *p in parts) {
            NSString *gid = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!gid.length) continue;
            BOOL exists = NO;
            for (FoxGroup *g in newGroups) if ([g.groupID isEqualToString:gid]) { exists = YES; break; }
            if (exists) continue;
            FoxGroup *g = [FoxGroup new];
            g.groupID = gid;
            g.name = gid;
            [newGroups addObject:g];
        }
        self.groups = newGroups;
        [self.tableView reloadData];
        [self updateCount];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)selectAllTapped {
    for (FoxGroup *g in _groups) [_selectedIDs addObject:g.groupID];
    [_tableView reloadData];
    [self updateCount];
}

- (void)clearTapped {
    [_selectedIDs removeAllObjects];
    [_tableView reloadData];
    [self updateCount];
}

- (void)updateCount {
    _countLabel.text = [NSString stringWithFormat:@"已选 %lu / %lu", (unsigned long)_selectedIDs.count, (unsigned long)_groups.count];
    [_forwardButton setTitle:[NSString stringWithFormat:@"转发到选中群（%lu）", (unsigned long)_selectedIDs.count] forState:UIControlStateNormal];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _groups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"g"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"g"];
    FoxGroup *g = _groups[indexPath.row];
    cell.textLabel.text = g.name;
    cell.detailTextLabel.text = g.groupID;
    cell.detailTextLabel.textColor = FoxSecondaryTextColor();
    cell.accessoryType = [_selectedIDs containsObject:g.groupID] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    FoxGroup *g = _groups[indexPath.row];
    if ([_selectedIDs containsObject:g.groupID]) [_selectedIDs removeObject:g.groupID];
    else [_selectedIDs addObject:g.groupID];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self updateCount];
}

- (void)forwardTapped {
    if (!_selectedIDs.count) { FoxShowAlert(self, @"还没有选择群", @"先勾选目标群，或点“全选”。"); return; }
    NSMutableArray<FoxGroup *> *targets = [NSMutableArray array];
    for (FoxGroup *g in _groups) if ([_selectedIDs containsObject:g.groupID]) [targets addObject:g];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"转发内容" message:[NSString stringWithFormat:@"将发送到 %lu 个群", (unsigned long)targets.count] preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"输入文本";
        tf.text = [UIPasteboard generalPasteboard].string;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"转发" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        NSString *text = [a.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!text.length) { FoxShowAlert(self, @"内容为空", @"请输入要转发的文本。"); return; }
        [self sendText:text toGroups:targets];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)sendText:(NSString *)text toGroups:(NSArray<FoxGroup *> *)targets {
    UIAlertController *progress = [UIAlertController alertControllerWithTitle:@"转发中" message:[NSString stringWithFormat:@"0 / %lu", (unsigned long)targets.count] preferredStyle:UIAlertControllerStyleAlert];
    UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [sp startAnimating];
    [progress.view addSubview:sp];
    sp.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [sp.centerXAnchor constraintEqualToAnchor:progress.view.centerXAnchor],
        [sp.bottomAnchor constraintEqualToAnchor:progress.view.bottomAnchor constant:-18],
    ]];
    [self presentViewController:progress animated:YES completion:nil];

    __block NSInteger done = 0, okCount = 0, failCount = 0;
    for (FoxGroup *g in targets) {
        [FoxBridge sendText:text toUser:nil group:g.groupID completion:^(BOOL ok, NSError *error) {
            done++;
            if (ok) okCount++; else failCount++;
            progress.message = [NSString stringWithFormat:@"%ld / %lu", (long)done, (unsigned long)targets.count];
            if (done >= (NSInteger)targets.count) {
                [progress dismissViewControllerAnimated:YES completion:^{
                    FoxShowAlert(self, @"转发完成", [NSString stringWithFormat:@"成功 %ld，失败 %ld", (long)okCount, (long)failCount]);
                }];
            }
        }];
    }
}

@end

#pragma mark - Auto reply

@interface FoxAutoReplyViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<FoxReplyRule *> *rules;
@end

@implementation FoxAutoReplyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"自动回复";
    self.view.backgroundColor = FoxGroupedBackground();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:self action:@selector(closeTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addRuleTapped)];

    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) style = UITableViewStyleInsetGrouped;
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:style];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = FoxGroupedBackground();
    [self.view addSubview:_tableView];

    _rules = [[[FoxStore shared] rules] mutableCopy] ?: [NSMutableArray array];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _tableView.frame = self.view.bounds;
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)save {
    [[FoxStore shared] saveRules:_rules];
    [_tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : _rules.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"开关" : @"规则";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"规则匹配的是收到的文本消息；同一用户 5 秒内只自动回复一次。";
    return @"关键词留空表示回复所有文本消息。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"r"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"r"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (indexPath.section == 0) {
        cell.textLabel.text = @"启用自动回复";
        cell.detailTextLabel.text = [FoxStore shared].enabled ? @"总开关已开启" : @"总开关已关闭，不会回复";
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = [FoxStore shared].enabled;
        sw.onTintColor = FoxAccent();
        [sw addTarget:self action:@selector(masterChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else {
        FoxReplyRule *rule = _rules[indexPath.row];
        cell.textLabel.text = rule.keyword.length ? rule.keyword : @"所有文本消息";
        cell.detailTextLabel.text = FoxShortText(rule.reply, 48);
        cell.detailTextLabel.textColor = FoxSecondaryTextColor();
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = rule.enabled;
        sw.tag = indexPath.row;
        sw.onTintColor = FoxAccent();
        [sw addTarget:self action:@selector(ruleSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    }
    return cell;
}

- (void)masterChanged:(UISwitch *)sw {
    [FoxStore shared].enabled = sw.on;
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)ruleSwitchChanged:(UISwitch *)sw {
    if (sw.tag < 0 || sw.tag >= (NSInteger)_rules.count) return;
    FoxReplyRule *rule = _rules[sw.tag];
    rule.enabled = sw.on;
    [self save];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) [self editRuleAtIndex:indexPath.row];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.section == 1) {
        [_rules removeObjectAtIndex:indexPath.row];
        [self save];
    }
}

- (void)addRuleTapped {
    [self presentRuleEditorAtIndex:-1];
}

- (void)editRuleAtIndex:(NSInteger)index {
    [self presentRuleEditorAtIndex:index];
}

- (void)presentRuleEditorAtIndex:(NSInteger)index {
    FoxReplyRule *rule = index >= 0 && index < (NSInteger)_rules.count ? _rules[index] : nil;
    NSString *title = rule ? @"编辑规则" : @"新增规则";
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:@"关键词为空 = 回复所有文本消息" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"关键词（可留空）";
        tf.text = rule.keyword;
    }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"自动回复内容";
        tf.text = rule.reply;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        NSString *kw = [a.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *reply = [a.textFields[1].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!reply.length) { FoxShowAlert(self, @"回复内容为空", @"请输入自动回复内容。"); return; }
        if (!rule) {
            FoxReplyRule *r = [FoxReplyRule new];
            r.keyword = kw;
            r.reply = reply;
            r.enabled = YES;
            [_rules addObject:r];
        } else {
            rule.keyword = kw;
            rule.reply = reply;
        }
        [self save];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end

#pragma mark - Moment editor interface

@interface FoxMomentEditorViewController : UIViewController
@property (nonatomic, strong) FoxMomentTask *task;
@property (nonatomic, copy) void (^onSave)(FoxMomentTask *task);
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UISwitch *repeatSwitch;
@end

#pragma mark - Moment list

@interface FoxMomentListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<FoxMomentTask *> *tasks;
@end

@implementation FoxMomentListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"定时动态";
    self.view.backgroundColor = FoxGroupedBackground();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:self action:@selector(closeTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTapped)];

    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) style = UITableViewStyleInsetGrouped;
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:style];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = FoxGroupedBackground();
    [self.view addSubview:_tableView];

    _tasks = [[[FoxStore shared] tasks] mutableCopy] ?: [NSMutableArray array];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _tableView.frame = self.view.bounds;
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)save {
    [[FoxStore shared] saveTasks:_tasks];
    [_tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _tasks.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"到点自动打开发布页";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"定时动态依赖 App 在前台运行；后台被系统挂起时，回到前台会立即补发。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"t"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"t"];
    FoxMomentTask *task = _tasks[indexPath.row];
    cell.textLabel.text = FoxShortText(task.text, 34);
    NSString *when = FoxDateText(task.fireDate);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", when, task.repeatDaily ? @" · 每天重复" : @""];
    cell.detailTextLabel.textColor = FoxSecondaryTextColor();

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = task.enabled;
    sw.tag = indexPath.row;
    sw.onTintColor = FoxAccent();
    [sw addTarget:self action:@selector(taskSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (void)taskSwitchChanged:(UISwitch *)sw {
    if (sw.tag < 0 || sw.tag >= (NSInteger)_tasks.count) return;
    FoxMomentTask *task = _tasks[sw.tag];
    task.enabled = sw.on;
    [self save];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self editTaskAtIndex:indexPath.row];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_tasks removeObjectAtIndex:indexPath.row];
        [self save];
    }
}

- (void)addTapped {
    [self presentEditorWithTask:nil];
}

- (void)editTaskAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_tasks.count) return;
    [self presentEditorWithTask:_tasks[index]];
}

- (void)presentEditorWithTask:(FoxMomentTask *)task {
    FoxMomentEditorViewController *editor = [[FoxMomentEditorViewController alloc] init];
    editor.task = task;
    __weak typeof(self) weakSelf = self;
    editor.onSave = ^(FoxMomentTask *newTask) {
        if (!task) [weakSelf.tasks addObject:newTask];
        [weakSelf save];
        [[FoxScheduler shared] checkNow];
    };
    [self presentViewController:FoxWrapInNav(editor) animated:YES completion:nil];
}

@end

#pragma mark - Moment editor

@implementation FoxMomentEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _task ? @"编辑动态" : @"新建动态";
    self.view.backgroundColor = FoxGroupedBackground();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(saveTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancelTapped)];

    UILabel *label = FoxMakeLabel(@"动态内容", 13, YES, FoxSecondaryTextColor());
    label.tag = 501;
    [self.view addSubview:label];

    _textView = [[UITextView alloc] initWithFrame:CGRectZero];
    _textView.font = [UIFont systemFontOfSize:15];
    _textView.backgroundColor = FoxCardBackground();
    _textView.layer.cornerRadius = 10;
    _textView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    _textView.text = _task.text;
    [self.view addSubview:_textView];

    UILabel *dateLabel = FoxMakeLabel(@"发布时间", 13, YES, FoxSecondaryTextColor());
    dateLabel.tag = 502;
    [self.view addSubview:dateLabel];

    _datePicker = [[UIDatePicker alloc] initWithFrame:CGRectZero];
    _datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    _datePicker.minimumDate = [NSDate date];
    if (@available(iOS 14.0, *)) {
        _datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    }
    if (_task.fireDate) _datePicker.date = _task.fireDate;
    [self.view addSubview:_datePicker];

    UILabel *repeatLabel = FoxMakeLabel(@"每天重复", 15, NO, FoxTextColor());
    repeatLabel.tag = 503;
    [self.view addSubview:repeatLabel];

    _repeatSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    _repeatSwitch.on = _task.repeatDaily;
    _repeatSwitch.onTintColor = FoxAccent();
    [self.view addSubview:_repeatSwitch];

    UILabel *hint = FoxMakeLabel(@"到点后如果 App 不在前台，会在回到前台时补发。", 12, NO, FoxSecondaryTextColor());
    hint.tag = 504;
    [self.view addSubview:hint];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat top = 16;
    if (@available(iOS 11.0, *)) top = self.view.safeAreaInsets.top + 12;
    UILabel *label = [self.view viewWithTag:501];
    label.frame = CGRectMake(20, top, w - 40, 20);
    _textView.frame = CGRectMake(16, top + 26, w - 32, 140);
    UILabel *dateLabel = [self.view viewWithTag:502];
    dateLabel.frame = CGRectMake(20, CGRectGetMaxY(_textView.frame) + 12, w - 40, 20);
    _datePicker.frame = CGRectMake(12, CGRectGetMaxY(dateLabel.frame) + 4, w - 24, 180);
    UILabel *repeatLabel = [self.view viewWithTag:503];
    repeatLabel.frame = CGRectMake(20, CGRectGetMaxY(_datePicker.frame) + 12, 120, 32);
    _repeatSwitch.center = CGPointMake(w - 44, repeatLabel.center.y);
    UILabel *hint = [self.view viewWithTag:504];
    hint.frame = CGRectMake(20, CGRectGetMaxY(repeatLabel.frame) + 8, w - 40, 40);
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveTapped {
    NSString *text = [_textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) { FoxShowAlert(self, @"内容为空", @"请输入要发布的动态内容。"); return; }

    FoxMomentTask *task = _task;
    if (!task) {
        task = [FoxMomentTask new];
        task.taskID = [[NSUUID UUID] UUIDString];
    }
    task.text = text;
    task.fireDate = _datePicker.date;
    task.repeatDaily = _repeatSwitch.on;
    task.enabled = YES;
    if (self.onSave) self.onSave(task);
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Settings entry

@interface FoxSettingsEntryView : UIView
@property (nonatomic, weak) UITableView *tableView;
@property (nonatomic, strong) NSIndexPath *indexPath;
- (instancetype)initWithTableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath;
- (void)updateFrame;
@end

@implementation FoxSettingsEntryView {
    UIButton *_button;
    UILabel *_chevron;
}

- (instancetype)initWithTableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _tableView = tableView;
        _indexPath = indexPath;
        self.backgroundColor = [UIColor clearColor];

        _button = [UIButton buttonWithType:UIButtonTypeSystem];
        _button.backgroundColor = FoxCardBackground();
        _button.layer.cornerRadius = 10;
        _button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _button.titleLabel.numberOfLines = 2;
        _button.titleLabel.textAlignment = NSTextAlignmentLeft;
        _button.contentEdgeInsets = UIEdgeInsetsMake(4, 14, 4, 36);

        NSString *line1 = @"🦊  狐狸助手";
        NSString *line2 = @"群发 · 定时动态 · 自动回复 · 群转发";
        NSString *title = [NSString stringWithFormat:@"%@\n%@", line1, line2];
        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:title];
        [attr addAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:15],
                              NSForegroundColorAttributeName: FoxTextColor()}
                        range:NSMakeRange(0, line1.length)];
        [attr addAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:11],
                              NSForegroundColorAttributeName: FoxSecondaryTextColor()}
                        range:NSMakeRange(line1.length + 1, line2.length)];
        [_button setAttributedTitle:attr forState:UIControlStateNormal];
        [_button addTarget:self action:@selector(openAssistant) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_button];

        _chevron = FoxMakeLabel(@"›", 22, NO, FoxSecondaryTextColor());
        _chevron.textAlignment = NSTextAlignmentCenter;
        _chevron.userInteractionEnabled = NO;
        [self addSubview:_chevron];

        if (_indexPath) [self updateFrame];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _button.frame = CGRectInset(self.bounds, 16, 2);
    _chevron.frame = CGRectMake(self.bounds.size.width - 50, 0, 30, self.bounds.size.height);
}

- (void)updateFrame {
    if (!_tableView || !_indexPath) return;
    CGRect row = [_tableView rectForRowAtIndexPath:_indexPath];
    self.frame = CGRectMake(0, CGRectGetMaxY(row), _tableView.bounds.size.width, 58);
}

- (void)openAssistant {
    [FoxUI presentAssistant];
}

@end

#pragma mark - FoxUI

static Class FoxAssistantViewControllerClass(void) {
    return NSClassFromString(@"FoxAssistantViewController");
}

@implementation FoxUI

+ (void)presentAssistant {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = FoxAssistantViewControllerClass();
        if (!cls) return;
        UIViewController *top = FoxTopViewController();
        if (!top) return;
        if ([top isKindOfClass:cls]) return;
        if ([top isKindOfClass:[UINavigationController class]] &&
            [((UINavigationController *)top).topViewController isKindOfClass:cls]) return;
        [top presentViewController:FoxWrapInNav([[cls alloc] init]) animated:YES completion:nil];
    });
}

+ (void)dismissAssistant {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = FoxAssistantViewControllerClass();
        if (!cls) return;
        UIViewController *top = FoxTopViewController();
        if (!top) return;
        if ([top isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)top;
            if ([nav.topViewController isKindOfClass:cls]) {
                [nav dismissViewControllerAnimated:YES completion:nil];
                return;
            }
        }
        if ([top isKindOfClass:cls]) {
            [top dismissViewControllerAnimated:YES completion:nil];
        } else if ([top.presentedViewController isKindOfClass:[UINavigationController class]] &&
                   [((UINavigationController *)top.presentedViewController).topViewController isKindOfClass:cls]) {
            [top dismissViewControllerAnimated:YES completion:nil];
        }
    });
}

+ (BOOL)isAssistantVisible {
    Class cls = FoxAssistantViewControllerClass();
    if (!cls) return NO;
    UIViewController *top = FoxTopViewController();
    if ([top isKindOfClass:cls]) return YES;
    if ([top isKindOfClass:[UINavigationController class]]) {
        return [((UINavigationController *)top).topViewController isKindOfClass:cls];
    }
    return NO;
}

+ (void)installSettingsEntryInViewController:(UIViewController *)viewController {
    if (!viewController) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UITableView *table = (UITableView *)FoxFindView(viewController.view, ^BOOL(UIView *v) {
            return [v isKindOfClass:[UITableView class]];
        });
        if (!table) {
            for (UIView *v in viewController.view.subviews) {
                if ([v isKindOfClass:[FoxSettingsEntryView class]]) return;
            }
            CGFloat h = 64;
            if (@available(iOS 11.0, *)) h += viewController.view.safeAreaInsets.bottom;
            FoxSettingsEntryView *entry = [[FoxSettingsEntryView alloc] initWithTableView:nil indexPath:nil];
            entry.frame = CGRectMake(16, viewController.view.bounds.size.height - h + 4, viewController.view.bounds.size.width - 32, 56);
            entry.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
            [viewController.view addSubview:entry];
            return;
        }

        for (UIView *v in table.subviews) {
            if ([v isKindOfClass:[FoxSettingsEntryView class]]) return;
        }

        NSIndexPath *anchor = nil;
        for (UITableViewCell *cell in table.visibleCells) {
            if (FoxFindLabel(cell.contentView, @"商城")) {
                anchor = [table indexPathForCell:cell];
                break;
            }
        }

        if (anchor) {
            FoxSettingsEntryView *entry = [[FoxSettingsEntryView alloc] initWithTableView:table indexPath:anchor];
            entry.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [table addSubview:entry];
            [entry updateFrame];
            return;
        }

        UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, 64)];
        footer.backgroundColor = [UIColor clearColor];
        FoxSettingsEntryView *entry = [[FoxSettingsEntryView alloc] initWithTableView:table indexPath:nil];
        entry.frame = CGRectMake(0, 4, table.bounds.size.width, 56);
        entry.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [footer addSubview:entry];
        table.tableFooterView = footer;
    });
}

@end
