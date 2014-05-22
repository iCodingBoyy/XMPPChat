//
//  YZChatMessageCell.m
//  XMPPChat
//
//  Created by 马远征 on 14-5-20.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "YZChatMessageCell.h"
#import "UIImage+YZMessage.h"

static const CGFloat KYZAvatarImageSize = 40.0f;
static const CGFloat KYZAvatarImagePadding = 8.0f;
static const CGFloat KYZTimeStampLabelHeight = 15.0f;
static const CGFloat KYZTimeStampLabelWidth = 140.0f;
static const CGFloat KYZTimeStampLabelPadding = 5.0f;
static const CGFloat KYZMessageBuddleViewPadding = 8.0f;


@interface YZChatMessageCell()
@property (nonatomic, strong) UILabel *timeStampLabel;
@property (nonatomic, assign) BOOL showMessageTime;
@property (nonatomic, assign) NSInteger MessageMark;
@end

@implementation YZChatMessageCell

#pragma mark -
#pragma mark dealloc

- (void)dealloc
{
    _timeStampLabel = nil;
    _messageBubbleView = nil;
    _avatorButton = nil;
    _indexPath = nil;
}

#pragma mark -
#pragma mark UI

- (UILabel*)timeStampLabel
{
    if (_timeStampLabel == nil)
    {
        CGRect frame = CGRectMake(0, 5.0f, KYZTimeStampLabelWidth, KYZTimeStampLabelHeight);
        _timeStampLabel = [[UILabel alloc]initWithFrame:frame];
        _timeStampLabel.center = CGPointMake(ScreenWidth()*0.5, _timeStampLabel.center.y);
        _timeStampLabel.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.380];
        _timeStampLabel.textAlignment = NSTextAlignmentCenter;
        _timeStampLabel.textColor = [UIColor whiteColor];
        _timeStampLabel.font =  [UIFont systemFontOfSize:12.0f];
    }
    return _timeStampLabel;
}

#pragma mark -
#pragma mark init
- (instancetype)initWithXmppMessage:(XmppMessage*)message
                           showTime:(BOOL)showMessageTime
                    reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self)
    {
        _showMessageTime = showMessageTime;
        _MessageMark = [message.outGoing integerValue];
        
        /* 增加时间标签*/
        [self.contentView addSubview:self.timeStampLabel];
        
        
        /* 添加图像按钮*/
        CGRect avatarBtnFrame = CGRectZero;
        CGFloat originY = (_showMessageTime ? KYZTimeStampLabelHeight : 0 ) + KYZTimeStampLabelPadding ;
        
        UIImage *avatarImage = nil;
        if ([message.outGoing integerValue] == YZMessageInComing)
        {
            // 接收的消息，图像在左边
            avatarBtnFrame = CGRectMake(KYZAvatarImagePadding, originY, KYZAvatarImageSize, KYZAvatarImageSize);
            avatarImage = [UIImage imageNamed:@"sender"];
        }
        else if ([message.outGoing integerValue] == YZMessageOutGoing)
        {
            // 发出的消息,图像在右边
            CGFloat originX = CGRectGetWidth(self.bounds)-KYZAvatarImageSize - KYZAvatarImagePadding;
            avatarBtnFrame = CGRectMake(originX, originY, KYZAvatarImageSize, KYZAvatarImageSize);
            avatarImage = [UIImage imageNamed:@"receiver"];
        }
        
        UIImage *userImage = [UIImage userAvatarImage:avatarImage imageType:YZAvatarImageSquare];
        
        _avatorButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_avatorButton setFrame:avatarBtnFrame];
        [_avatorButton setImage:userImage forState:UIControlStateNormal];
        [_avatorButton addTarget:self action:@selector(avatarBtnClick) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_avatorButton];
        
        
        // 初始化气泡视图
        CGFloat leftMargin = 0.0f;
        CGFloat rightMargin = 0.0f;
        if ([message.outGoing integerValue] == YZMessageOutGoing)
        {
            rightMargin = KYZAvatarImageSize + KYZAvatarImagePadding*2;
        }
        else if ([message.outGoing integerValue] == YZMessageInComing)
        {
            leftMargin = KYZAvatarImageSize + KYZAvatarImagePadding*2;
        }
        
        CGFloat buddleViewOriginY = (_showMessageTime ? _timeStampLabel.frame.size.height + KYZTimeStampLabelPadding : KYZTimeStampLabelPadding) + KYZMessageBuddleViewPadding;
        CGFloat buddleViewHeight = self.contentView.frame.size.height - buddleViewOriginY;
        CGRect buddleViewFrame = CGRectMake(leftMargin, buddleViewOriginY, self.contentView.frame.size.width - leftMargin - rightMargin, buddleViewHeight);
        _messageBubbleView = [[YZMessageBubbleView alloc]initWithFrame:buddleViewFrame message:message];
        _messageBubbleView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleBottomMargin;
        [self.contentView addSubview:_messageBubbleView];
        
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.backgroundColor = [UIColor clearColor];
        self.superview.backgroundColor = [UIColor clearColor];
        self.textLabel.hidden = YES;
        self.detailTextLabel.hidden = YES;
        self.imageView.hidden = YES;
    }
    return self;
}

- (void)UpdateCellWithMessage:(XmppMessage*)message showTime:(BOOL)showMessageTime
{
    // 更新时间标签
    _showMessageTime = showMessageTime;
    _MessageMark = [message.outGoing integerValue];
    
    _timeStampLabel.hidden = !_showMessageTime;
    if (_showMessageTime)
    {
        _timeStampLabel.text = [NSDateFormatter localizedStringFromDate:message.timeStamp
                                                              dateStyle:NSDateFormatterMediumStyle
                                                              timeStyle:NSDateFormatterShortStyle];
    }
    
    // 更新用户图像
    UIImage *avatarImage = nil;
    if ([message.outGoing integerValue] == YZMessageOutGoing)
    {
        avatarImage = [UIImage imageNamed:@"sender"];
    }
    else if ([message.outGoing integerValue] == YZMessageInComing)
    {
        avatarImage = [UIImage imageNamed:@"receiver"];
    }
    UIImage *userImage = [UIImage userAvatarImage:avatarImage imageType:YZAvatarImageSquare];
    [_avatorButton setImage:userImage forState:UIControlStateNormal];
    
    // 更新气泡视图
    [_messageBubbleView UpdateCellWithMessage:message];
}

+ (CGFloat)calculateCellHeightWithMessage:(XmppMessage*)message showTime:(BOOL)showMessageTime
{
    CGFloat timeStampHeight = (showMessageTime ? KYZTimeStampLabelHeight+KYZTimeStampLabelPadding:KYZTimeStampLabelPadding);
    CGFloat messageBuddleViewHeight = [YZMessageBubbleView calculateCellHeightWithMessage:message];
    return timeStampHeight + KYZMessageBuddleViewPadding*2 + MAX(KYZAvatarImageSize, messageBuddleViewHeight);
}

#pragma mark -
#pragma mark UIControl Action

- (void)avatarBtnClick
{
    
}

#pragma mark -
#pragma mark override

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect avatarBtnFrame = _avatorButton.frame;
    avatarBtnFrame.origin.y = (_showMessageTime ? KYZTimeStampLabelHeight : 0 ) + KYZTimeStampLabelPadding ;
    avatarBtnFrame.origin.x = (_MessageMark == YZMessageOutGoing)?CGRectGetWidth(self.bounds)-KYZAvatarImageSize - KYZAvatarImagePadding:KYZAvatarImagePadding;
    [_avatorButton setFrame:avatarBtnFrame];
    

    CGRect buddleViewFrame = _messageBubbleView.frame;
    buddleViewFrame.origin.y = (_showMessageTime ? _timeStampLabel.frame.size.height + KYZTimeStampLabelPadding : KYZTimeStampLabelPadding) + KYZMessageBuddleViewPadding;
    buddleViewFrame.origin.x = (_MessageMark == YZMessageOutGoing) ? 0:KYZAvatarImageSize + KYZAvatarImagePadding*2;
    [_messageBubbleView setFrame:buddleViewFrame];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _timeStampLabel.text = nil;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
}

@end
