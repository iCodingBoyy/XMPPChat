//
//  YZChatToolBoxView.m
//  XMPPChat
//
//  Created by 马远征 on 14-4-2.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "YZChatToolBoxView.h"

@interface YZToolBoxItemView : UIView
@property (nonatomic, strong) NSString *itemName;
@property (nonatomic, strong, readonly) UIButton *button;
@end

@implementation YZToolBoxItemView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.backgroundColor = [UIColor colorWithRed:0.875 green:0.875 blue:0.875 alpha:1.0];
        
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        [_button setFrame:CGRectMake((frame.size.width - 54)*0.5, 15, 54, 54)];
        [self addSubview:_button];
    }
    return self;
}



- (void)setItemName:(NSString *)itemName
{
    if (_itemName != itemName)
    {
        _itemName = itemName;
        [self setNeedsDisplay];
    }
}

- (void)layoutSubviews
{
}

- (void)drawRect:(CGRect)rect
{
    if (_itemName)
    {
        UIFont *font = [UIFont fontWithName:@"HelveticaNeue-CondensedBlack" size:14.0];
        [_itemName drawInRect:CGRectMake(0, rect.size.height - 24, rect.size.width, 24)
                     withFont:font
                lineBreakMode:NSLineBreakByWordWrapping
                    alignment:NSTextAlignmentCenter];
    }
}

@end

#define KImageArray @"sharemore_pic",@"sharemore_video",@"sharemore_location",@"sharemore_friendcard"
#define KItemName @"照片",@"拍摄",@"位置",@"名片"


@implementation YZChatToolBoxView

- (id)initWithFrame:(CGRect)frame  block:(ClickBtnBlock)block
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _btnBlock = block;
        self.backgroundColor = [UIColor colorWithRed:0.875 green:0.875 blue:0.875 alpha:1.0];
        
        self.pagingEnabled = YES;
        self.showsHorizontalScrollIndicator = NO;
        self.showsVerticalScrollIndicator = NO;
        
        NSArray *imageArray = [NSArray arrayWithObjects:KImageArray, nil];
        NSArray *itemNameArray = [NSArray arrayWithObjects:KItemName, nil];
        
        for ( int i = 0; i < 4; i++)
        {
            NSUInteger page = floor(i/4)/4;
            NSUInteger floorlayer = floor((i/4)%4);
            
            NSString *imageName = [imageArray objectAtIndex:i];
            NSString *itemName = [itemNameArray objectAtIndex:i];
            
            CGRect rect =  CGRectMake((i%4)*80 + page*frame.size.width, floorlayer*95, 80, 95);
            YZToolBoxItemView *itemView = [[YZToolBoxItemView alloc]initWithFrame:rect];
            [itemView setItemName:itemName];
            [itemView.button setBackgroundImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
            [itemView.button addTarget:self action:@selector(clickToShare:) forControlEvents:UIControlEventTouchUpInside];
            [itemView.button setTag:i+10010];
            [self addSubview:itemView];
        }
    }
    return self;
}

- (void)clickToShare:(UIButton*)sender
{
    _btnBlock(sender.tag - 10010);
}



@end
