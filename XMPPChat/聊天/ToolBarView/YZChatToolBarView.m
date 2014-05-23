//
//  YZChatToolBarView.m
//  XMPPChat
//
//  Created by 马远征 on 14-4-1.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "YZChatToolBarView.h"
#import <QuartzCore/QuartzCore.h>
#import "YZChatFaceBoardView.h"
#import "YZChatToolBoxView.h"


@interface YZChatToolBarView() <UITextViewDelegate,UIScrollViewDelegate>
@property (nonatomic, strong) UITextView *msgTextView;
@property (nonatomic, strong) UIButton *speakButton;
@property (nonatomic, strong) UIButton *faceButton;
@property (nonatomic, strong) UIButton *boxButton;
@property (nonatomic, strong) UIButton *voiceButton;
@property (nonatomic, assign) BOOL isKeyboardShow;
@property (nonatomic, assign) BOOL isFaceBoardShow;
@property (nonatomic, assign) BOOL isToolBoxShow;
@property (nonatomic, strong) YZChatFaceBoardView *faceboardView;
@property (nonatomic, strong) YZChatToolBoxView *toolBoxView;
@property (nonatomic, strong) UIView *toolBarView;
@end

@implementation YZChatToolBarView
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.backgroundColor = [UIColor whiteColor];
        [self initToolBarView];
        [self initFaceBoardAndToolBoxView];
        [self registerNotification];
    }
    return self;
}


- (void)registerNotification
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)initFaceBoardAndToolBoxView
{
    _faceboardView = [[YZChatFaceBoardView alloc]initWithFrame:CGRectMake(0, self.frame.size.height, KScreenWidth, 216)];
    _faceboardView.backgroundColor = [UIColor orangeColor];
    _faceboardView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [self addSubview:_faceboardView];
    
    __block YZChatToolBarView *this = self;
    CGRect TbFrame = CGRectMake(0, self.frame.size.height, KScreenWidth, 216);
    _toolBoxView = [[YZChatToolBoxView alloc]initWithFrame:TbFrame block:^(NSInteger buttonTag)
    {
        if (this->_delegate && [this->_delegate respondsToSelector:@selector(YZChatToolBoxButtonClick:)])
        {
            [this->_delegate YZChatToolBoxButtonClick:buttonTag];
        }
    }];
    _toolBoxView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [self addSubview:_toolBoxView];
}

- (void)initToolBarView
{
    _toolBarView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, KScreenWidth, 50)];
    _toolBarView.autoresizesSubviews = YES;

    UIImageView *toolBarBgImageView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, KScreenWidth, 50)];
    toolBarBgImageView.image = [[UIImage imageNamed:@"toolbar_bottom_bar"]stretchableImageWithLeftCapWidth:5 topCapHeight:25];
    toolBarBgImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [_toolBarView addSubview:toolBarBgImageView];
    
    CGFloat height = _toolBarView.frame.size.height;
    
    // 语音按钮
    _voiceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_voiceButton setFrame:CGRectMake(10, height - 42, 34, 34)];
    UIImage *norImage = [UIImage imageNamed:@"chat_bottom_voice_nor"];
    UIImage *highlightImage = [UIImage imageNamed:@"chat_bottom_voice_press"];
    [_voiceButton setBackgroundImage:norImage forState:UIControlStateNormal];
    [_voiceButton setBackgroundImage:highlightImage forState:UIControlStateHighlighted];
    [_voiceButton addTarget:self action:@selector(clickToSpeak:) forControlEvents:UIControlEventTouchUpInside];
    _voiceButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [_toolBarView addSubview:_voiceButton];
    
    
    // 消息文本
    _msgTextView = [[UITextView alloc]initWithFrame:CGRectMake(50, 8, 185, 34)];
    _msgTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _msgTextView.layer.borderColor = [[UIColor colorWithWhite:.8 alpha:1.0] CGColor];
    _msgTextView.layer.borderWidth = 0.65f;
    _msgTextView.layer.cornerRadius = 6.0f;
    _msgTextView.scrollEnabled = YES;
    _msgTextView.scrollsToTop = NO;
    _msgTextView.userInteractionEnabled = YES;
    _msgTextView.textColor = [UIColor blackColor];
    _msgTextView.font = [UIFont systemFontOfSize:14.0f];
    _msgTextView.returnKeyType = UIReturnKeySend;
    _msgTextView.delegate = self;
    [_toolBarView addSubview:_msgTextView];
    
    // 录音按钮
    _speakButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_speakButton setFrame:CGRectMake(50, height - 45, 180, 40)];
    [_speakButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_textfield"] forState:UIControlStateNormal];
    [_speakButton addTarget:self action:@selector(clickToRecordVoice:) forControlEvents:UIControlEventTouchUpInside];
    [_speakButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [_speakButton setTitle:@"按住说话" forState:UIControlStateNormal];
    [_speakButton setTitle:@"按住说话" forState:UIControlStateHighlighted];
    [_speakButton setHidden:YES];
    _speakButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [_toolBarView addSubview:_speakButton];
    
    // 表情按钮
    _faceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_faceButton setFrame:CGRectMake(243, height - 42, 34, 34)];
    UIImage *faceNorImage = [UIImage imageNamed:@"chat_bottom_smile_nor"];
    UIImage *faceHighlightImage = [UIImage imageNamed:@"chat_bottom_smile_press"];
    [_faceButton setBackgroundImage:faceNorImage forState:UIControlStateNormal];
    [_faceButton setBackgroundImage:faceHighlightImage forState:UIControlStateHighlighted];
    [_faceButton addTarget:self action:@selector(clickToPickFace:) forControlEvents:UIControlEventTouchUpInside];
    _faceButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [_toolBarView addSubview:_faceButton];
    
    // 工具栏按钮
    _boxButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_boxButton setFrame:CGRectMake(280, height - 42, 34, 34)];
    UIImage *boxNorImage = [UIImage imageNamed:@"chat_bottom_up_nor"];
    UIImage *boxHighlightImage = [UIImage imageNamed:@"chat_bottom_up_press"];
    [_boxButton setBackgroundImage:boxNorImage forState:UIControlStateNormal];
    [_boxButton setBackgroundImage:boxHighlightImage forState:UIControlStateHighlighted];
    [_boxButton addTarget:self action:@selector(clickToPickTools:) forControlEvents:UIControlEventTouchUpInside];
     _boxButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [_toolBarView addSubview:_boxButton];
    
    [self addSubview:_toolBarView];
}

- (CGFloat)offsetOfScrollView:(UIScrollView*)scrollView keyBoardHeight:(CGFloat)height
{
    CGFloat result = scrollView.frame.size.height - scrollView.contentSize.height;
    result = result > 0 ? result : 0;
    CGFloat offset = fabsf(height) - result;
    offset = offset > 0 ? offset : 0;
    return offset;
}


#pragma mark -
#pragma mark 设置工具条按钮背景

- (void)showkeyboardBgForFaceButton
{
    [_faceButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_keyboard_nor"]
                           forState:UIControlStateNormal];
    [_faceButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_keyboard_press"]
                           forState:UIControlStateHighlighted];
}

- (void)showFaceBgForFaceButton
{
    [_faceButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_smile_nor"]
                           forState:UIControlStateNormal];
    [_faceButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_smile_press"]
                           forState:UIControlStateHighlighted];
}

- (void)showKeyBoardBgForBoxButon
{
    [_boxButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_keyboard_nor"]
                           forState:UIControlStateNormal];
    [_boxButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_keyboard_press"]
                           forState:UIControlStateHighlighted];
}

- (void)showBoxBgForBoxButton
{
    [_boxButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_up_nor"]
                          forState:UIControlStateNormal];
    [_boxButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_up_press"]
                          forState:UIControlStateHighlighted];
}

- (void)showKeyBoardBgForVoiceButon
{
    [_voiceButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_keyboard_nor.png"]
                      forState:UIControlStateNormal];
    [_voiceButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_keyboard_press.png"]
                      forState:UIControlStateHighlighted];
}

- (void)showVoiceBgForSpeakButton
{
    [_voiceButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_voice_nor.png"]
                            forState:UIControlStateNormal];
    [_voiceButton setBackgroundImage:[UIImage imageNamed:@"chat_bottom_voice_press.png"]
                            forState:UIControlStateHighlighted];
}


#pragma mark -
#pragma mark 工具条按钮交互响应

//点击录制按钮
- (void)clickToRecordVoice:(UIButton*)sender
{
    
}

// 点击说话按钮
- (void)clickToSpeak:(UIButton*)sender
{
    if (_msgTextView.hidden)
    {
        _isKeyboardShow = YES;
        _isFaceBoardShow = NO;
        _isToolBoxShow = NO;
        
        _msgTextView.hidden = NO;
        _speakButton.hidden = YES;
        
        [self showVoiceBgForSpeakButton];
        
        [_msgTextView becomeFirstResponder];
        [self textViewDidChange:_msgTextView];
    }
    else
    {
        [self resizeTextView];
        [self showKeyBoardBgForVoiceButon];
        if (_isFaceBoardShow)
        {
            [self showFaceBgForFaceButton];
        }
        if (_isToolBoxShow)
        {
            [self showBoxBgForBoxButton];
        }
        
        _isKeyboardShow = NO;
        _isFaceBoardShow = NO;
        _isToolBoxShow = NO;
        
        _msgTextView.hidden = YES;
        _speakButton.hidden = NO;
        
        if ([_msgTextView isFirstResponder])
        {
            [_msgTextView resignFirstResponder];
        }
        else
        {
            [UIView animateWithDuration:.35
                             animations:^{
                                 _scrollView.transform = CGAffineTransformIdentity;
                                 self.transform = CGAffineTransformIdentity;
                             }
                             completion:^(BOOL finished) {
                                 
                                 _faceboardView.transform = CGAffineTransformIdentity;
                                 _toolBoxView.transform = CGAffineTransformIdentity;
                             }];
        }
    }
}

// 点击选取表情按钮
- (void)clickToPickFace:(UIButton*)sender
{
    // 键盘，表情，工具面板都不显示
    if ( !_isFaceBoardShow && !_isKeyboardShow && !_isToolBoxShow)
    {
        if (_msgTextView.hidden)
        {
            _msgTextView.hidden = NO;
            _speakButton.hidden = YES;
            _isKeyboardShow = YES;
            
            [self showVoiceBgForSpeakButton];
            [_msgTextView becomeFirstResponder];
            [self textViewDidChange:_msgTextView];
        }
        else
        {
            _isFaceBoardShow = YES;
            [self showkeyboardBgForFaceButton];
            _faceboardView.transform = CGAffineTransformMakeTranslation(0, -216);
            [UIView animateWithDuration:.35
                             animations:^{
                                 CGFloat offset = [self offsetOfScrollView:_scrollView keyBoardHeight:216];
                                 _scrollView.transform = CGAffineTransformMakeTranslation(0, -offset);
                                 self.transform = CGAffineTransformMakeTranslation(0, -216);
                                 
                             }];
        }
        
    }
    // 当前显示键盘
    else if (_isKeyboardShow)
    {
        _isKeyboardShow = NO;
        _isFaceBoardShow = YES;
        _isToolBoxShow = NO;
        
        [self showkeyboardBgForFaceButton];
        
        if ([_msgTextView isFirstResponder])
        {
            [_msgTextView resignFirstResponder];
        }
    }
    // 当前显示表情
    else if (_isFaceBoardShow)
    {
        _isFaceBoardShow = NO;
        _isKeyboardShow = YES;
        _isToolBoxShow = NO;
        
        [self showFaceBgForFaceButton];
        
        if ( ![_msgTextView isFirstResponder])
        {
            [_msgTextView becomeFirstResponder];
        }
    }
    // 当前显示工具栏
    else if (_isToolBoxShow)
    {
        _isToolBoxShow = NO;
        _isFaceBoardShow = YES;
        _isKeyboardShow = NO;
        [self showBoxBgForBoxButton];
        [self showkeyboardBgForFaceButton];
        
        // 隐藏工具栏，显示表情
        // do something
        [UIView animateWithDuration:.35
                         animations:^{
                             _faceboardView.transform = CGAffineTransformMakeTranslation(0, -216);
                             _toolBoxView.transform = CGAffineTransformIdentity;
                         }];
    }
    
}

// 点击工具栏按钮
- (void)clickToPickTools:(UIButton*)sender
{
    if ( !_isFaceBoardShow && !_isKeyboardShow && !_isToolBoxShow)
    {
        if (_msgTextView.hidden)
        {
            _msgTextView.hidden = NO;
            _speakButton.hidden = YES;
            _isKeyboardShow = YES;
            
            [self showVoiceBgForSpeakButton];
            
            [_msgTextView becomeFirstResponder];
            [self textViewDidChange:_msgTextView];
        }
        else
        {
            _isToolBoxShow = YES;
            [self showKeyBoardBgForBoxButon];
            _toolBoxView.transform = CGAffineTransformMakeTranslation(0, -216);
            [UIView animateWithDuration:.35
                             animations:^{
                                 CGFloat offset = [self offsetOfScrollView:_scrollView keyBoardHeight:216];
                                 _scrollView.transform = CGAffineTransformMakeTranslation(0, -offset);
                                 self.transform = CGAffineTransformMakeTranslation(0, -216);
                             }];
        }

    }
    else if (_isKeyboardShow)
    {
        _isKeyboardShow = NO;
        _isFaceBoardShow = NO;
        _isToolBoxShow = YES;
        [self showKeyBoardBgForBoxButon];
        
        if ([_msgTextView isFirstResponder])
        {
            [_msgTextView resignFirstResponder];
        }
    }
    else if (_isToolBoxShow)
    {
        _isFaceBoardShow = NO;
        _isKeyboardShow = YES;
        _isToolBoxShow = NO;
        [self showBoxBgForBoxButton];
        
        if ( ![_msgTextView isFirstResponder])
        {
            [_msgTextView becomeFirstResponder];
        }
    }
    else if (_isFaceBoardShow)
    {
        _isFaceBoardShow = NO;
        _isToolBoxShow = YES;
        _isKeyboardShow = NO;
        [self showFaceBgForFaceButton];
        [self showKeyBoardBgForBoxButon];
        
        // 交换工具和表情面板
        [UIView animateWithDuration:.35
                         animations:^{
                             _toolBoxView.transform = CGAffineTransformMakeTranslation(0, -216);
                             _faceboardView.transform =CGAffineTransformIdentity;
                         }];
    }
}



#pragma mark -
#pragma mark keyBoardNotification

- (void)keyBoardWillShow:(NSNotification *)notify
{
    if (_isKeyboardShow)
    {
        CGRect keyboardRect = [[notify.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
        double duration = [[notify.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        CGFloat transY = - keyboardRect.size.height;
        [UIView animateWithDuration:duration
                         animations:^{
                             _faceboardView.transform = CGAffineTransformIdentity;
                             _toolBoxView.transform = CGAffineTransformIdentity;
                             CGFloat offset = [self offsetOfScrollView:_scrollView keyBoardHeight:transY];
                             _scrollView.transform = CGAffineTransformMakeTranslation(0, -offset);
                             self.transform = CGAffineTransformMakeTranslation(0, transY);
                         }];
    }
}

- (void)keyBoardWillHide:(NSNotification *)notify
{
    if (!_isToolBoxShow && !_isFaceBoardShow)
    {
        double duration = [[notify.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        [UIView animateWithDuration:duration
                         animations:^{
                             _faceboardView.transform = CGAffineTransformIdentity;
                             _toolBoxView.transform = CGAffineTransformIdentity;
                             _scrollView.transform = CGAffineTransformIdentity;
                             self.transform = CGAffineTransformIdentity;
                         }];
    }
    else if (_isFaceBoardShow )
    {
        [UIView animateWithDuration:.35
                         animations:^{
                             _faceboardView.transform = CGAffineTransformMakeTranslation(0, -216);
                             CGFloat offset = [self offsetOfScrollView:_scrollView keyBoardHeight:216];
                             _scrollView.transform = CGAffineTransformMakeTranslation(0, -offset);
                             self.transform = CGAffineTransformMakeTranslation(0, -216);
                         }];
    }
    else if (_isToolBoxShow)
    {
        [UIView animateWithDuration:.35
                         animations:^{
                             _toolBoxView.transform = CGAffineTransformMakeTranslation(0, -216);
                             CGFloat offset = [self offsetOfScrollView:_scrollView keyBoardHeight:216];
                             _scrollView.transform = CGAffineTransformMakeTranslation(0, -offset);
                             self.transform = CGAffineTransformMakeTranslation(0, -216);
                         }];
    }
    
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView;
{
    if (_isFaceBoardShow)
    {
        [self showFaceBgForFaceButton];
    }
    if (_isToolBoxShow)
    {
        [self showBoxBgForBoxButton];
    }
    _isKeyboardShow = YES;
    _isFaceBoardShow = NO;
    _isToolBoxShow = NO;
    return YES;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if (range.length != 1 && [text isEqualToString:@"\n"])
    {
        // 如果文本长度不为0，则发送文本
        if (textView.text.length > 0 && _delegate &&
            [_delegate respondsToSelector:@selector(YZChatTextViewDidSend:)])
        {
            [_delegate YZChatTextViewDidSend:textView.text];
        }
        textView.text = nil;
        [self resizeTextView];
        return NO;
    }
    return YES;
}

- (void)resizeTextView
{
    CGFloat span =  _toolBarView.frame.size.height - 50;
    if (span != 0)
    {
        CGRect toolBarViewFrame = _toolBarView.frame;
        toolBarViewFrame.size = CGSizeMake(KScreenWidth, 50);
        _toolBarView.frame = toolBarViewFrame;
        
        CGRect sRect = self.frame;
        sRect.size.height -= span;
        sRect.origin.y += span ;
        self.frame = sRect;
    }
}


- (void)textViewDidChange:(UITextView *)textView
{
    CGSize size = textView.contentSize;
    if (size.height < 34)
    {
        size.height = 34;
    }
    
    if (size.height >= 84)
    {
        size.height = 84;
    }
    
    if (size.height != textView.frame.size.height)
    {
        CGFloat span = size.height - textView.frame.size.height;
        
        CGRect toolBarViewFrame = _toolBarView.frame;
        toolBarViewFrame.size = CGSizeMake(KScreenWidth, size.height + 16);
        _toolBarView.frame = toolBarViewFrame;
        
        CGRect sRect = self.frame;
        sRect.size.height += span;
        sRect.origin.y -= span ;
        self.frame = sRect;
    }
}


- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (CGRectContainsPoint(self.bounds, point))
    {
        return YES;
    }
    else
    {
        [self endEditing:YES];
        if (_isKeyboardShow || _isFaceBoardShow || _isToolBoxShow)
        {
            [UIView animateWithDuration:.35
                             animations:^{
                                 _scrollView.transform = CGAffineTransformIdentity;
                                 self.transform = CGAffineTransformIdentity;
                             }completion:^(BOOL finished) {
                                 _faceboardView.transform = CGAffineTransformIdentity;
                                 _toolBoxView.transform = CGAffineTransformIdentity;
                             }];
        }
        
        if (_isFaceBoardShow)
        {
            [self showFaceBgForFaceButton];
        }
        if (_isToolBoxShow)
        {
            [self showBoxBgForBoxButton];
        }
        
        _isKeyboardShow = NO;
        _isFaceBoardShow = NO;
        _isToolBoxShow = NO;
        return NO;
    }

}

@end
