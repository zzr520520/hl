#import "FoxUIShared.h"

static UIViewController *FoxMakeController(NSString *className) {
    Class cls = NSClassFromString(className);
    return cls ? [[cls alloc] init] : nil;
}

#pragma mark - Header

@interface FoxAssistantHeaderView : UIView
@end

@implementation FoxAssistantHeaderView {
    UILabel *_icon;
    UILabel *_title;
    UILabel *_subtitle;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _icon = FoxMakeLabel(@"🦊", 38, YES, FoxTextColor());
        _title = FoxMakeLabel(@"狐狸助手", 23, YES, FoxTextColor());
        _subtitle = FoxMakeLabel(@"群发 · 定时动态 · 自动回复 · 群转发", 12, NO, FoxSecondaryTextColor());
        [self addSubview:_icon];
        [self addSubview:_title];
        [self addSubview:_subtitle];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    _icon.frame = CGRectMake(4, 12, 62, 52);
    _title.frame = CGRectMake(68, 18, w - 80, 32);
    _subtitle.frame = CGRectMake(68, 50, w - 80, 24);
}

@end

#pragma mark - Dashboard

@interface FoxAssistantViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISwitch *masterSwitch;
@end

@implementation FoxAssistantViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"狐狸助手";
    self.view.backgroundColor = FoxGroupedBackground();

    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:self action:@selector(closeTapped)];
    self.navigationItem.rightBarButtonItem = close;

    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) style = UITableViewStyleInsetGrouped;
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:style];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = FoxGroupedBackground();
    _tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    [self.view addSubview:_tableView];

    FoxAssistantHeaderView *header = [[FoxAssistantHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 96)];
    _tableView.tableHeaderView = header;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _tableView.frame = self.view.bounds;
    if (_tableView.tableHeaderView) {
        CGRect f = _tableView.tableHeaderView.frame;
        f.size.width = _tableView.bounds.size.width;
        _tableView.tableHeaderView.frame = f;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_tableView reloadData];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return 2;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"功能";
    if (section == 1) return @"状态";
    return @"说明";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return @"关闭总开关后，自动回复与定时动态停止；手动群发不受影响。";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.detailTextLabel.textColor = FoxSecondaryTextColor();

    if (indexPath.section == 0) {
        NSArray *titles = @[@"群成员群发", @"定时动态", @"自动回复", @"群转发"];
        NSArray *details = @[@"选成员、全选/清除、批量私聊", @"到点自动打开发布页", @"关键词匹配后自动回复", @"转发文本到多个群"];
        cell.textLabel.text = titles[indexPath.row];
        cell.detailTextLabel.text = details[indexPath.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"总开关";
            cell.detailTextLabel.text = [FoxStore shared].enabled ? @"已开启" : @"已关闭";
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [FoxStore shared].enabled;
            sw.onTintColor = FoxAccent();
            [sw addTarget:self action:@selector(masterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            _masterSwitch = sw;
        } else {
            cell.textLabel.text = @"当前群";
            NSString *gid = [FoxBridge currentGroupID];
            cell.detailTextLabel.text = gid.length ? gid : @"未检测到群聊，可在群成员页手动选群";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else {
        cell.textLabel.text = @"使用说明";
        cell.detailTextLabel.text = @"双指双击任意界面也可打开";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)masterSwitchChanged:(UISwitch *)sw {
    [FoxStore shared].enabled = sw.on;
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    if (sw.on) [[FoxScheduler shared] checkNow];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        UIViewController *vc = nil;
        if (indexPath.row == 0) vc = FoxMakeController(@"FoxMemberPickerViewController");
        else if (indexPath.row == 1) vc = FoxMakeController(@"FoxMomentListViewController");
        else if (indexPath.row == 2) vc = FoxMakeController(@"FoxAutoReplyViewController");
        else vc = FoxMakeController(@"FoxGroupForwardViewController");
        if (!vc) return;
        [self presentViewController:FoxWrapInNav(vc) animated:YES completion:nil];
    } else if (indexPath.section == 2) {
        FoxShowAlert(self, @"狐狸助手", @"1. 双指双击任意界面打开面板。\n2. 群成员群发：选择群 → 全选/清除 → 输入内容发送。\n3. 定时动态：到点自动打开发布页，需要 App 在前台。\n4. 自动回复：关键词为空表示回复所有文本消息。\n5. 群转发：选择多个群，转发输入或剪贴板内容。");
    }
}

@end

#pragma mark - Member picker

@interface FoxMemberPickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<FoxGroup *> *groups;
@property (nonatomic, copy) NSString *selectedGroupID;
@property (nonatomic, strong) NSArray<FoxMember *> *members;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedIDs;
@property (nonatomic, strong) UIButton *groupButton;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation FoxMemberPickerViewController

- (instancetype)init {
    self = [super init];
    if (self) _selectedIDs = [NSMutableSet set];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"群成员群发";
    self.view.backgroundColor = FoxGroupedBackground();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:self action:@selector(closeTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addManualTapped)];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 58;
    _tableView.backgroundColor = FoxGroupedBackground();
    [self.view addSubview:_tableView];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 98)];
    header.backgroundColor = FoxGroupedBackground();

    _groupButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _groupButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _groupButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    _groupButton.layer.cornerRadius = 8;
    _groupButton.layer.borderWidth = 1;
    _groupButton.layer.borderColor = [FoxSecondaryTextColor() colorWithAlphaComponent:0.25].CGColor;
    _groupButton.backgroundColor = FoxCardBackground();
    _groupButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    [_groupButton setTitle:@"选择群…" forState:UIControlStateNormal];
    [_groupButton addTarget:self action:@selector(groupTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:_groupButton];

    UIButton *all = [UIButton buttonWithType:UIButtonTypeSystem];
    [all setTitle:@"全选" forState:UIControlStateNormal];
    all.titleLabel.font = [UIFont systemFontOfSize:13];
    [all addTarget:self action:@selector(selectAllTapped) forControlEvents:UIControlEventTouchUpInside];
    all.tag = 101;
    [header addSubview:all];

    UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
    [clear setTitle:@"清除" forState:UIControlStateNormal];
    clear.titleLabel.font = [UIFont systemFontOfSize:13];
    [clear addTarget:self action:@selector(clearTapped) forControlEvents:UIControlEventTouchUpInside];
    clear.tag = 102;
    [header addSubview:clear];

    _countLabel = FoxMakeLabel(@"已选 0 / 0", 12, NO, FoxSecondaryTextColor());
    _countLabel.textAlignment = NSTextAlignmentRight;
    [header addSubview:_countLabel];

    _tableView.tableHeaderView = header;

    UIView *bottom = [[UIView alloc] initWithFrame:CGRectZero];
    bottom.backgroundColor = FoxCardBackground();
    [self.view addSubview:bottom];
    bottom.tag = 200;

    _sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _sendButton.backgroundColor = FoxAccent();
    [_sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    _sendButton.layer.cornerRadius = 10;
    [_sendButton setTitle:@"发送给选中成员" forState:UIControlStateNormal];
    [_sendButton addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottom addSubview:_sendButton];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spinner.hidesWhenStopped = YES;
    _spinner.tag = 201;
    [bottom addSubview:_spinner];

    [self loadInitialGroup];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    UIView *bottom = [self.view viewWithTag:200];
    CGFloat bottomH = 64;
    if (@available(iOS 11.0, *)) bottomH += self.view.safeAreaInsets.bottom;
    bottom.frame = CGRectMake(0, h - bottomH, w, bottomH);
    _tableView.frame = CGRectMake(0, 0, w, h - bottomH);
    _sendButton.frame = CGRectMake(16, 9, w - 32, 46);
    _spinner.center = CGPointMake(w - 30, 32);

    UIView *header = _tableView.tableHeaderView;
    if (header) {
        header.frame = CGRectMake(0, 0, w, 98);
        _groupButton.frame = CGRectMake(16, 10, w - 32, 36);
        UIButton *all = (UIButton *)[header viewWithTag:101];
        UIButton *clear = (UIButton *)[header viewWithTag:102];
        all.frame = CGRectMake(16, 54, 56, 32);
        clear.frame = CGRectMake(80, 54, 56, 32);
        _countLabel.frame = CGRectMake(150, 54, w - 166, 32);
    }
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadInitialGroup {
    NSString *current = [FoxBridge currentGroupID];
    if (current.length) {
        _selectedGroupID = current;
        [self refreshGroupTitle];
        [self fetchMembers];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [FoxBridge fetchJoinedGroups:^(NSArray<FoxGroup *> *groups, NSError *error) {
        if (!weakSelf) return;
        weakSelf.groups = groups;
        if (groups.count) {
            weakSelf.selectedGroupID = groups.firstObject.groupID;
            [weakSelf refreshGroupTitle];
            [weakSelf fetchMembers];
        } else if (error) {
            [weakSelf promptGroupID];
        }
    }];
}

- (void)refreshGroupTitle {
    NSString *title = _selectedGroupID.length ? _selectedGroupID : @"选择群…";
    for (FoxGroup *g in _groups) {
        if ([g.groupID isEqualToString:_selectedGroupID]) { title = g.name; break; }
    }
    [_groupButton setTitle:[NSString stringWithFormat:@"群：%@  ▾", title] forState:UIControlStateNormal];
}

- (void)groupTapped {
    if (!_groups.count) { [self promptGroupID]; return; }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择群" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (FoxGroup *g in _groups) {
        [sheet addAction:[UIAlertAction actionWithTitle:g.name style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self.selectedGroupID = g.groupID;
            [self.selectedIDs removeAllObjects];
            [self refreshGroupTitle];
            [self fetchMembers];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"手动输入群 ID" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self promptGroupID];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = _groupButton;
    sheet.popoverPresentationController.sourceRect = _groupButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)promptGroupID {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"输入群 ID" message:@"无法自动获取群列表时，可手动输入群 ID" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"groupID";
        tf.text = self.selectedGroupID;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        NSString *gid = [a.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (gid.length) {
            self.selectedGroupID = gid;
            [self.selectedIDs removeAllObjects];
            [self refreshGroupTitle];
            [self fetchMembers];
        }
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)fetchMembers {
    if (!_selectedGroupID.length) return;
    [_spinner startAnimating];
    __weak typeof(self) weakSelf = self;
    [FoxBridge fetchMembersOfGroup:_selectedGroupID completion:^(NSArray<FoxMember *> *members, NSError *error) {
        if (!weakSelf) return;
        [weakSelf.spinner stopAnimating];
        if (error) {
            [weakSelf membersFailed:error];
            return;
        }
        weakSelf.members = members;
        [weakSelf.selectedIDs removeAllObjects];
        [weakSelf.tableView reloadData];
        [weakSelf updateCount];
        if (!members.count) {
            FoxShowAlert(weakSelf, @"没有拿到群成员", @"请确认群 ID 正确、当前账号在群内，且腾讯 IM 已登录。");
        }
    }];
}

- (void)membersFailed:(NSError *)error {
    FoxShowAlert(self, @"获取群成员失败", error.localizedDescription);
}

- (void)selectAllTapped {
    for (FoxMember *m in _members) [_selectedIDs addObject:m.userID];
    [_tableView reloadData];
    [self updateCount];
}

- (void)clearTapped {
    [_selectedIDs removeAllObjects];
    [_tableView reloadData];
    [self updateCount];
}

- (void)updateCount {
    _countLabel.text = [NSString stringWithFormat:@"已选 %lu / %lu", (unsigned long)_selectedIDs.count, (unsigned long)_members.count];
    [_sendButton setTitle:[NSString stringWithFormat:@"发送给选中成员（%lu）", (unsigned long)_selectedIDs.count] forState:UIControlStateNormal];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _members.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"m"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"m"];
    FoxMember *m = _members[indexPath.row];
    cell.textLabel.text = m.name;
    cell.detailTextLabel.text = m.userID;
    cell.detailTextLabel.textColor = FoxSecondaryTextColor();
    cell.accessoryType = [_selectedIDs containsObject:m.userID] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    FoxMember *m = _members[indexPath.row];
    if ([_selectedIDs containsObject:m.userID]) [_selectedIDs removeObject:m.userID];
    else [_selectedIDs addObject:m.userID];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self updateCount];
}

- (void)addManualTapped {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"手动添加成员" message:@"输入 userID，一行一个或用逗号分隔" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"userID1, userID2"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        NSString *raw = a.textFields.firstObject.text ?: @"";
        NSArray *parts = [raw componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",，;；\n "]];
        NSMutableArray *newMembers = [self.members mutableCopy] ?: [NSMutableArray array];
        for (NSString *p in parts) {
            NSString *uid = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!uid.length) continue;
            BOOL exists = NO;
            for (FoxMember *m in newMembers) if ([m.userID isEqualToString:uid]) { exists = YES; break; }
            if (exists) continue;
            FoxMember *m = [FoxMember new];
            m.userID = uid;
            m.name = uid;
            [newMembers addObject:m];
        }
        self.members = newMembers;
        [self.tableView reloadData];
        [self updateCount];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)sendTapped {
    if (!_selectedIDs.count) { FoxShowAlert(self, @"还没有选择成员", @"先点“全选”或手动勾选成员。"); return; }
    NSMutableArray<FoxMember *> *targets = [NSMutableArray array];
    for (FoxMember *m in _members) if ([_selectedIDs containsObject:m.userID]) [targets addObject:m];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"发送内容" message:[NSString stringWithFormat:@"将私聊发送给 %lu 位成员", (unsigned long)targets.count] preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"输入要发送的文本";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"发送" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        NSString *text = [a.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!text.length) { FoxShowAlert(self, @"内容为空", @"请输入要发送的文本。"); return; }
        [self sendText:text toMembers:targets];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)sendText:(NSString *)text toMembers:(NSArray<FoxMember *> *)targets {
    UIAlertController *progress = [UIAlertController alertControllerWithTitle:@"发送中" message:[NSString stringWithFormat:@"0 / %lu", (unsigned long)targets.count] preferredStyle:UIAlertControllerStyleAlert];
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
    for (FoxMember *m in targets) {
        [FoxBridge sendText:text toUser:m.userID group:nil completion:^(BOOL ok, NSError *error) {
            done++;
            if (ok) okCount++; else failCount++;
            progress.message = [NSString stringWithFormat:@"%ld / %lu", (long)done, (unsigned long)targets.count];
            if (done >= (NSInteger)targets.count) {
                [progress dismissViewControllerAnimated:YES completion:^{
                    FoxShowAlert(self, @"发送完成", [NSString stringWithFormat:@"成功 %ld，失败 %ld", (long)okCount, (long)failCount]);
                }];
            }
        }];
    }
}

@end
