//
//  SettingViewController.m
//  XMPPChat
//
//  Created by 马远征 on 14-3-31.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "SettingViewController.h"
#import "AppDelegate.h"
#import "LoginAndRegisterView.h"
#import "YZXMPPManager.h"

@interface SettingViewController () <UITableViewDataSource,UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation SettingViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.title = @"设置";
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    UIView *contentView = [[UIView alloc]initWithFrame:[[UIScreen mainScreen]applicationFrame]];
    contentView.backgroundColor = [UIColor whiteColor];
    self.view = contentView;
}

- (void)initRightBarButton
{
    UIButton *buton = [UIButton buttonWithType:UIButtonTypeCustom];
    [buton setFrame:CGRectMake(0, 0, 60, 34)];
    [buton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [buton setTitleColor:[UIColor blueColor] forState:UIControlStateHighlighted];
    [buton setTitle:@"注销" forState:UIControlStateNormal];
    [buton setTitle:@"注销" forState:UIControlStateHighlighted];
    [buton addTarget:self action:@selector(clickToLogout) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:buton];
}

- (void)initTableView
{
    _tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, KScreenWidth, KScreenHeight - 114)];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initRightBarButton];
    [self initTableView];
}

- (void)clickToLogout
{
    [[YZXMPPManager sharedYZXMPP]disconnect];
    AppDelegate *delegate = [[UIApplication sharedApplication]delegate];
    LoginAndRegisterView *authView = (LoginAndRegisterView*)(delegate.userAuthView);
    [delegate.window addSubview:authView];
    [delegate.tabbarController setSelectedIndex:0];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
#pragma mark -
#pragma mark UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 10;
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
    return cell;
}
@end
