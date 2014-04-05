//
//  AppDelegate.h
//  XMPPChat
//
//  Created by 马远征 on 14-3-28.
//  Copyright (c) 2014年 ___FULLUSERNAME___. All rights reserved.
//

#import <UIKit/UIKit.h>

@class LoginAndRegisterView;
@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) LoginAndRegisterView *userAuthView;
@property (nonatomic, strong) UITabBarController *tabbarController;
@end
