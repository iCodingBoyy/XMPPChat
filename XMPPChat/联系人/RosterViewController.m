//
//  RosterViewController.m
//  XMPPChat
//
//  Created by 马远征 on 14-3-31.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "RosterViewController.h"
#import "YZXMPPManager.h"
#import "MKEntryPanel.h"
#import "YZChatViewController.h"

@interface RosterViewController () <UITableViewDataSource,UITableViewDelegate,YZXMPPMgrDelegate>
{
    
}
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *JIDArray;
@end

@implementation RosterViewController

#pragma mark -
#pragma mark dealloc

- (void)dealloc
{
     [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark -
#pragma mark init

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.title = @"联系人";
        
        
    }
    return self;
}

#pragma mark -
#pragma mark loadView

- (void)loadView
{
    [super loadView];
    UIView *contentView = [[UIView alloc]initWithFrame:[[UIScreen mainScreen]applicationFrame]];
    contentView.backgroundColor = [UIColor whiteColor];
    self.view = contentView;
}

- (void)initRightBarButton
{
    UIImage *image = [UIImage imageNamed:@"account_add"];
    UIButton *buton = [UIButton buttonWithType:UIButtonTypeCustom];
    [buton setFrame:CGRectMake(0, 0, image.size.width, image.size.height)];
    [buton setBackgroundImage:image forState:UIControlStateNormal];
    [buton addTarget:self action:@selector(clickToAddBuddy) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:buton];
}

- (void)initTableView
{
    _tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, KScreenWidth, KScreenHeight - 114)];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
}

- (void)registerNotification
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(receiveRefreshNotify)
                                                name:@"EVENT_CONTACT_REFRESH_NOTIFY" object:nil];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self registerNotification];
    [self initRightBarButton];
    [self initTableView];
    
    YZXMPPManager *xmppMgr =  [YZXMPPManager sharedYZXMPP];
    xmppMgr.delegate = self;
    [xmppMgr fethcRosterOnServer];
    
}

- (void)receiveRefreshNotify
{
    if (_JIDArray && _JIDArray.count > 0)
    {
        [_JIDArray removeAllObjects];
    }
    [self.tableView reloadData];
    [[YZXMPPManager sharedYZXMPP]fethcRosterOnServer];
}

- (void)clickToAddBuddy
{
    [MKEntryPanel showPanelWithTitle:NSLocalizedString(@"请输入好友ID", @"")
                              inView:self.view
                       onTextEntered:^(NSString* enteredString)
     {
         NSLog(@"Entered: %@", enteredString);
         [[YZXMPPManager sharedYZXMPP]xmppAddFriendsSubscribe:enteredString];
     }];
}


- (void)YZXmppMgr:(YZXMPPManager *)XMPPMgr newBuddyOnline:(NSString *)userJID
{
    NSLog(@"-----%s------%@",__FUNCTION__,userJID);
//    if ( ![_JIDArray containsObject:userJID] )
//    {
//        [_JIDArray addObject:userJID];
//    }
//    [self.tableView reloadData];
}

- (void)YZXmppMgr:(YZXMPPManager *)XMPPMgr buddyWentOffline:(NSString *)userJID
{
     NSLog(@"-----%s------%@",__FUNCTION__,userJID);
}

- (void)YZXmppMgr:(YZXMPPManager *)XMPPMgr didReceiveJID:(XMPPJID *)userJID
{
    NSLog(@"-----%s------%@",__FUNCTION__,userJID);
    if (_JIDArray == nil)
    {
        _JIDArray = [[NSMutableArray alloc]init];
    }
    if ( ![_JIDArray containsObject:userJID] )
    {
        [_JIDArray addObject:userJID];
    }
    [self.tableView reloadData];
}

#pragma mark -
#pragma mark UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
	return _JIDArray.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    if (indexPath.row < _JIDArray.count)
    {
        XMPPJID *jid = [_JIDArray objectAtIndex:indexPath.row];
        if ([jid isBare])
        {
            cell.textLabel.text = jid.user;
        }
        else
        {
            cell.textLabel.text = jid.bare;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    XMPPJID *jid = [_JIDArray objectAtIndex:indexPath.row];
    YZChatViewController *IMChatVC = [[YZChatViewController alloc]initWithXmppJID:jid];
    IMChatVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:IMChatVC animated:YES];
    IMChatVC = nil;
}
@end
