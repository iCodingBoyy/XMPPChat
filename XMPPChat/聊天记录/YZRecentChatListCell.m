//
//  YZRecentChatListCell.m
//  XMPPChat
//
//  Created by 马远征 on 14-4-10.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "YZRecentChatListCell.h"
#import <QuartzCore/QuartzCore.h>

@implementation YZRecentChatListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        _timeStampLabel = [[UILabel alloc]init];
        _timeStampLabel.backgroundColor = [UIColor clearColor];
        _timeStampLabel.textAlignment = NSTextAlignmentRight;
        _timeStampLabel.font = [UIFont fontWithName:@"Helvetica" size:15.0];
        [self.contentView addSubview:_timeStampLabel];
        
        self.imageView.layer.cornerRadius = 2.0;
        self.imageView.layer.masksToBounds = YES;
        self.imageView.layer.borderColor = [UIColor whiteColor].CGColor;
        self.imageView.layer.borderWidth = 2.0;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect imageframe = self.imageView.frame;
    imageframe.origin.x = 5;
    imageframe.origin.y = 5;
    imageframe.size.height = self.frame.size.height - 10;
    imageframe.size.width = imageframe.size.height;
    self.imageView.frame = imageframe;
    
    CGRect textlabelframe = self.textLabel.frame;
    textlabelframe.origin.x = imageframe.size.width+ 15;
    textlabelframe.origin.y = 5;
    textlabelframe.size.height = 24;
    textlabelframe.size.width = 200;
    self.textLabel.frame = textlabelframe;
    
    CGRect detailtextlabelframe = self.detailTextLabel.frame;
    detailtextlabelframe.origin.x = imageframe.size.width+ 15;
    detailtextlabelframe.origin.y = self.frame.size.height - 30;
    detailtextlabelframe.size.height = 24;
    detailtextlabelframe.size.width = 240;
    self.detailTextLabel.frame = detailtextlabelframe;
    
    _timeStampLabel.frame = CGRectMake(self.frame.size.width - 150, 5, 150, 24);
}



@end
