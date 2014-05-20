//
//  LoginAndRegisterView.m
//  XMPPChat
//
//  Created by 马远征 on 14-3-31.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "LoginAndRegisterView.h"
#import "TPKeyboardAvoidingScrollView.h"
#import "YZXMPPManager.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "YZTextField.h"


@interface LoginAndRegisterView() <UIScrollViewDelegate,UITextFieldDelegate>
{
    TPKeyboardAvoidingScrollView *_leftScrollView;
    TPKeyboardAvoidingScrollView *_rightScrollView;
    
    UIScrollView *_switchScrollView;
    
    UIImageView *_userImageView;
    
    UITextField *_lNameTextField;
    UITextField *_lPwdTextField;
    
    YZTextField *_rNameTextField;
    YZTextField *_rPwdTextField;
}
@end

@implementation LoginAndRegisterView

- (id)initWithFrame:(CGRect)frame
{
    frame.origin.y -= 20;
    frame.size.height += 20;
    self = [super initWithFrame:frame];
    if (self)
    {
        self.backgroundColor = [UIColor whiteColor];
        [self initSwitchScrollView];
        [self initScrollView];
        [self initUserImageView];
        [self initLoginTextFieldView];
        [self initRegisterTextField];
        [self initLoginButton];
        [self initRegisterButton];
    }
    return self;
}

- (void)initSwitchScrollView
{
    CGRect frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    _switchScrollView = [[UIScrollView alloc]initWithFrame:frame];
    _switchScrollView.contentSize = CGSizeMake(self.frame.size.width*2, self.frame.size.height);
    _switchScrollView.delegate = self;
    _switchScrollView.pagingEnabled = YES;
    _switchScrollView.scrollEnabled = NO;
    [self addSubview:_switchScrollView];
}

- (void)initScrollView
{
    CGRect lframe =  CGRectMake(0, 40, KScreenWidth, KScreenHeight-40);
    _leftScrollView = [[TPKeyboardAvoidingScrollView alloc]initWithFrame:lframe];
    [_switchScrollView addSubview:_leftScrollView];
    
    CGRect rframe =  CGRectMake(KScreenWidth, 40, KScreenWidth, KScreenHeight-40);
    _rightScrollView = [[TPKeyboardAvoidingScrollView alloc]initWithFrame:rframe];
    [_switchScrollView addSubview:_rightScrollView];
}

- (void)initUserImageView
{
    CGRect frame =  CGRectMake(KScreenWidth*0.5 - 45, 40, 90, 90);
    _userImageView = [[UIImageView alloc]initWithFrame:frame];
    _userImageView.image = [UIImage imageNamed:@"user_image.jpeg"];
    [_leftScrollView addSubview:_userImageView];
}

- (void)initLoginTextFieldView
{
    UIImage *bgImage = [UIImage imageNamed:@"login_textfield"];
    UIImageView *bgImageView = [[UIImageView alloc]initWithImage:bgImage];
    bgImageView.frame = CGRectMake(KScreenWidth*0.5 - 150.5, 160, 301, 94);
    bgImageView.userInteractionEnabled = YES;
    
    UILabel *namelabel = [[UILabel alloc]initWithFrame:CGRectMake(10, 15, 40, 24)];
    namelabel.backgroundColor = [UIColor clearColor];
    namelabel.text = @"账号:";
    [bgImageView addSubview:namelabel];
    
    _lNameTextField = [[UITextField alloc]initWithFrame:CGRectMake(60, 15, 220, 24)];
    _lNameTextField.backgroundColor = [UIColor clearColor];
    _lNameTextField.textColor = [UIColor blackColor];
    _lNameTextField.font = [UIFont fontWithName:@"Helvetica" size:16];
    _lNameTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _lNameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _lNameTextField.delegate = self;
    [bgImageView addSubview:_lNameTextField];
    
    UILabel *pwslabel = [[UILabel alloc]initWithFrame:CGRectMake(10, 60, 40, 24)];
    pwslabel.backgroundColor = [UIColor clearColor];
    pwslabel.text = @"密码:";
    [bgImageView addSubview:pwslabel];
    
    _lPwdTextField = [[UITextField alloc]initWithFrame:CGRectMake(60, 60, 220, 24)];
    _lPwdTextField.backgroundColor = [UIColor clearColor];
    _lPwdTextField.textColor = [UIColor blackColor];
    _lPwdTextField.font = [UIFont fontWithName:@"Helvetica" size:16];
    _lPwdTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _lPwdTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [bgImageView addSubview:_lPwdTextField];
    
    [_leftScrollView addSubview:bgImageView];
}

- (void)initRegisterTextField
{
    _rNameTextField = [[YZTextField alloc]initWithFrame:CGRectMake(20, 100, 280, 44)];
    _rNameTextField.backgroundColor = [UIColor clearColor];
    _rNameTextField.textColor = [UIColor blackColor];
    _rNameTextField.font = [UIFont fontWithName:@"Helvetica" size:16];
    _rNameTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _rNameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _rNameTextField.delegate = self;
    _rNameTextField.leftView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 20, 0)];
    _rNameTextField.leftViewMode = UITextFieldViewModeAlways;
    [_rightScrollView addSubview:_rNameTextField];
    
    _rPwdTextField = [[YZTextField alloc]initWithFrame:CGRectMake(20, 170, 280, 44)];
    _rPwdTextField.backgroundColor = [UIColor clearColor];
    _rPwdTextField.textColor = [UIColor blackColor];
    _rPwdTextField.font = [UIFont fontWithName:@"Helvetica" size:16];
    _rPwdTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _rPwdTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _rPwdTextField.delegate = self;
    _rPwdTextField.leftView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 20, 0)];
    _rPwdTextField.leftViewMode = UITextFieldViewModeAlways;
    [_rightScrollView addSubview:_rPwdTextField];
}

- (void)initLoginButton
{
    UIImage *image = [UIImage imageNamed:@"login_btn_blue_nor"];
    UIImage *highlightImage = [UIImage imageNamed:@"login_btn_blue_press"];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setFrame:CGRectMake(KScreenWidth*0.5 - 145, 300, 290, 44)];
    [button setBackgroundImage:image forState:UIControlStateNormal];
    [button setBackgroundImage:highlightImage forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(clickToLogIn) forControlEvents:UIControlEventTouchUpInside];
    [_leftScrollView addSubview:button];
}

- (void)initRegisterButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setFrame:CGRectMake(KScreenWidth - 100 , KScreenHeight - 100, 80, 34)];
    [button setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
    [button setTitle:@"注册账号" forState:UIControlStateNormal];
    [button setTitle:@"注册账号" forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(clickToRegister) forControlEvents:UIControlEventTouchUpInside];
    [_leftScrollView addSubview:button];
    
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setFrame:CGRectMake(10 , KScreenHeight - 100, 80, 34)];
    [backButton setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
    [backButton setTitle:@"返回登录" forState:UIControlStateNormal];
    [backButton setTitle:@"返回登录" forState:UIControlStateHighlighted];
    [backButton addTarget:self action:@selector(clickToBack) forControlEvents:UIControlEventTouchUpInside];
    [_rightScrollView addSubview:backButton];
    
    UIImage *norImage = [UIImage imageNamed:@"delete_btn_nor"];
    UIImage *highlightImage = [UIImage imageNamed:@"delete_btn_press"];
    norImage = [norImage stretchableImageWithLeftCapWidth:11.5 topCapHeight:20.5];
    highlightImage = [highlightImage stretchableImageWithLeftCapWidth:11.5 topCapHeight:20.5];
    
    UIButton *registerbutton = [UIButton buttonWithType:UIButtonTypeCustom];
    [registerbutton setFrame:CGRectMake(KScreenWidth*0.5 - 145, 300, 290, 44)];
    [registerbutton setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
    [registerbutton setTitle:@"注册账号" forState:UIControlStateNormal];
    [registerbutton setTitle:@"注册账号" forState:UIControlStateHighlighted];
    [registerbutton setBackgroundImage:norImage forState:UIControlStateNormal];
    [registerbutton setBackgroundImage:highlightImage forState:UIControlStateHighlighted];
    [registerbutton addTarget:self action:@selector(clickToDoneRegister) forControlEvents:UIControlEventTouchUpInside];
    [_rightScrollView addSubview:registerbutton];
}


#pragma mark -
#pragma mark UIControl Action

- (void)clickToLogIn
{
    KResignFirstResponder(_lNameTextField);
    KResignFirstResponder(_lPwdTextField);
    
    if (_lNameTextField.text.length <= 0 || _lPwdTextField.text.length <= 0)
    {
        return;
    }
    MBProgressHUD *progressHUD = [[MBProgressHUD alloc]initWithView:self];
    progressHUD.mode = MBProgressHUDModeIndeterminate;
    progressHUD.labelText = @"请稍后";
    [self addSubview:progressHUD];
    [progressHUD show:YES];
    
    __block LoginAndRegisterView *this = self;
    __block MBProgressHUD *thisHud = progressHUD;
    YZXMPPManager *xmppMgr = [YZXMPPManager sharedYZXMPP];
    [xmppMgr LoginWithName:_lNameTextField.text
                  passWord:_lPwdTextField.text
                  complete:^{
        DEBUG_METHOD(@"--logincomplete--");
                      [[NSNotificationCenter defaultCenter]postNotificationName:@"EVENT_CONTACT_REFRESH_NOTIFY" object:nil];
                      [thisHud hide:YES];
                      [this performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:YES];
//                      [xmppMgr fetchRoster];
//                      [xmppMgr setNickname:@"myz11" forUser:@"myz11"];
//                      [xmppMgr xmppAddFriendsSubscribe:@"jxw3042_"];
//                      [xmppMgr xmppAddFriendsSubscribe:@"myz33"];
//                      [xmppMgr xmppAddFriendsSubscribe:@"myz44"];
//                      [xmppMgr xmppAddFriendsSubscribe:@"myz77"];
//                      [xmppMgr xmppAddFriendsSubscribe:@"myz88"];
//                      [xmppMgr fetchUserWithXMPPJID:@"myz77"];
                      
    } failure:^(XMPPErrorCode errorCode) {
        [thisHud hide:YES];
//        DEBUG_METHOD(@"--loginError--%ld",errorCode);
    }];
}

- (void)clickToDoneRegister
{
    KResignFirstResponder(_rNameTextField);
    KResignFirstResponder(_rPwdTextField);
    
    if (_rNameTextField.text.length <= 0 || _rPwdTextField.text.length <= 0)
    {
        return;
    }

    
    MBProgressHUD *progressHUD = [[MBProgressHUD alloc]initWithView:self];
    progressHUD.mode = MBProgressHUDModeIndeterminate;
    progressHUD.labelText = @"请稍后";
    [self addSubview:progressHUD];
    [progressHUD show:YES];
    
    __block LoginAndRegisterView *this = self;
    __block MBProgressHUD *thisHud = progressHUD;
    
    YZXMPPManager *xmppMgr = [YZXMPPManager sharedYZXMPP];
    [xmppMgr registerWithName:_rNameTextField.text
                     passWord:_rPwdTextField.text
                     complete:^{
        
        [thisHud hide:YES];
        [this->_switchScrollView setContentOffset:CGPointMake(0, 0) animated:YES];
        
    } failure:^(XMPPErrorCode errorCode) {
        [thisHud hide:YES];
    }];
}


- (void)clickToRegister
{
    [_switchScrollView setContentOffset:CGPointMake(self.frame.size.width, 0) animated:YES];
}

- (void)clickToBack
{
    [_switchScrollView setContentOffset:CGPointMake(0, 0) animated:YES];
}

#pragma mark -
#pragma mark drawRect

- (void)drawRect:(CGRect)rect
{
    UIImage *bgImage = [UIImage imageNamed:@"login_bg.jpg"];
    [bgImage drawInRect:rect];
}

//- (void)textFieldDidBeginEditing:(UITextField *)textField
//{
//    [_leftScrollView adjustOffsetToIdealIfNeeded];
//    []
//}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}


@end
