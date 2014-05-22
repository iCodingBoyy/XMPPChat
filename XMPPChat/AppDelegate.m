//
//  AppDelegate.m
//  XMPPChat
//
//  Created by 马远征 on 14-3-28.
//  Copyright (c) 2014年 ___FULLUSERNAME___. All rights reserved.
//

#import "AppDelegate.h"
#import "RecentMsgViewController.h"
#import "RosterViewController.h"
#import "NewsViewController.h"
#import "SettingViewController.h"
#import "LoginAndRegisterView.h"
#import "YZXMPPManager.h"

@implementation AppDelegate

- (void)initNavBarTitleStyle
{
    UIColor *textColor = [UIColor colorWithRed:245.0/255.0
                                         green:245.0/255.0
                                          blue:245.0/255.0 alpha:1.0];
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-CondensedBlack" size:21.0];
    
    if ([[[UIDevice currentDevice]systemVersion]floatValue] >= 60000)
    {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
        NSShadow *shadow = [[NSShadow alloc] init];
        shadow.shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8];
        shadow.shadowOffset = CGSizeMake(0, 1);
        [[UINavigationBar appearance] setTitleTextAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                                                               textColor, NSForegroundColorAttributeName,
                                                               shadow, NSShadowAttributeName,
                                                               font, NSFontAttributeName, nil]];
#endif
    }
    else
    {
        UIColor *shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8];
        NSValue *value =  [NSValue valueWithCGSize:CGSizeMake(0.0f, 1.0f)];
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                              textColor,UITextAttributeTextColor,
                              font,UITextAttributeFont,
                              shadowColor,UITextAttributeTextShadowColor,
                              value,UITextAttributeTextShadowOffset,nil];
        [[UINavigationBar appearance] setTitleTextAttributes:dict];
    }
}

- (void)customNavBarBg
{
    [self initNavBarTitleStyle];
    // 自定义导航栏标题
    NSString *imageName = iOS7 ? @"nav_bg_image_ios7" :@"nav_bg_image";
    UIImage *navBarImage = [UIImage imageNamed:imageName];
    [[UINavigationBar appearance]setBackgroundImage:navBarImage forBarMetrics: UIBarMetricsDefault];
}

- (void)initTabBarController
{
    RecentMsgViewController *recentMsgVC = [[RecentMsgViewController alloc]init];
    UINavigationController *recentMsgNaV = [[UINavigationController alloc]initWithRootViewController:recentMsgVC];
    [self customNavBarBg];
    UITabBarItem *recentItem = [[UITabBarItem alloc]initWithTitle:@"消息" image:[UIImage imageNamed:@"tab_recent"] tag:0];
    recentMsgNaV.tabBarItem = recentItem;
    
    RosterViewController *rosterVC = [[RosterViewController alloc]init];
    UINavigationController *rosterNaV = [[UINavigationController alloc]initWithRootViewController:rosterVC];
    UITabBarItem *rosterItem = [[UITabBarItem alloc]initWithTitle:@"好友" image:[UIImage imageNamed:@"tab_buddy"] tag:1];
    rosterNaV.tabBarItem = rosterItem;
    
    NewsViewController *newsVC = [[NewsViewController alloc]init];
    UINavigationController *newsNaV = [[UINavigationController alloc]initWithRootViewController:newsVC];
    UITabBarItem *newsItem = [[UITabBarItem alloc]initWithTitle:@"动态" image:[UIImage imageNamed:@"tab_qzone"] tag:2];
    newsNaV.tabBarItem = newsItem;
    
    SettingViewController *settingVC = [[SettingViewController alloc]init];
    UINavigationController *settingNaV = [[UINavigationController alloc]initWithRootViewController:settingVC];
    UITabBarItem *settingItem = [[UITabBarItem alloc]initWithTitle:@"设置" image:[UIImage imageNamed:@"tab_me"] tag:3];
    settingNaV.tabBarItem = settingItem;
    
    NSArray *viewControllers = [NSArray arrayWithObjects:recentMsgNaV,rosterNaV,newsNaV,settingNaV, nil];
    
    _tabbarController = [[UITabBarController alloc]init];
    _tabbarController.viewControllers = viewControllers;
    self.window .rootViewController = _tabbarController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [YZXMPPManager sharedYZXMPP];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self initTabBarController];
    
//    YZXMPPManager *xmppMgr = [YZXMPPManager sharedYZXMPP];
//    [xmppMgr LoginWithName:@"myz11"
//                  passWord:@"123"
//                  complete:^{} failure:^(XMPPErrorCode errorCode) {}];

    
    self.window.backgroundColor = [UIColor blackColor];
    [self.window makeKeyAndVisible];
    
    CGRect frame = [[UIScreen mainScreen]applicationFrame];
    _userAuthView = [[LoginAndRegisterView alloc]initWithFrame:frame];
    [self.window addSubview:_userAuthView];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[YZXMPPManager sharedYZXMPP]disconnect];
}

@end
