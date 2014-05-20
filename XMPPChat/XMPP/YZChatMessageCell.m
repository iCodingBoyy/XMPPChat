//
//  YZChatMessageCell.m
//  XMPPChat
//
//  Created by 马远征 on 14-5-20.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "YZChatMessageCell.h"

@interface YZChatMessageCell()
@property (nonatomic, strong) UILabel *timeStampLabel;

@end

@implementation YZChatMessageCell

#pragma mark -
#pragma mark UI

- (UILabel*)timeStampLabel
{
    if (_timeStampLabel == nil)
    {
        CGRect frame = CGRectMake(0, 5.0f, 140.0f, 15.0f);
        _timeStampLabel = [[UILabel alloc]initWithFrame:frame];
        _timeStampLabel.center = CGPointMake(ScreenWidth()*0.5, _timeStampLabel.center.y);
        _timeStampLabel.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.380];
        _timeStampLabel.textAlignment = NSTextAlignmentCenter;
        _timeStampLabel.textColor = [UIColor whiteColor];
        _timeStampLabel.font =  [UIFont systemFontOfSize:12.0f];
    }
    return _timeStampLabel;
}

- (instancetype)initWithXmppMessage:(XmppMessage*)message reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self)
    {
        
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
       
    }
    return self;
}

#pragma mark -
#pragma mark override

- (void)layoutSubviews
{
    [super layoutSubviews];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    if (_timeStampLabel)
    {
        _timeStampLabel.text = nil;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
}

@end
