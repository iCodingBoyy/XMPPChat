//
//  YZMessageBubbleView.m
//  XMPPChat
//
//  Created by 马远征 on 14-5-21.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "YZMessageBubbleView.h"

@interface YZMessageBubbleView()
@end

@implementation YZMessageBubbleView


#pragma mark -
#pragma mark dealloc

- (void)dealloc
{
    _message = nil;
}

#pragma mark -
#pragma mark UI


#pragma mark -
#pragma mark init

- (id)initWithFrame:(CGRect)frame message:(XmppMessage *)message
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _message = message;
        
        // 气泡视图
        _buddleImageView = [[UIImageView alloc]initWithFrame:self.bounds];
        _buddleImageView.userInteractionEnabled = YES;
        [self addSubview:_buddleImageView];
        
        if (_displayTextView == nil)
        {
            _displayTextView = [[UITextView alloc]initWithFrame:CGRectZero];
            _displayTextView.textColor = [UIColor blackColor];
            _displayTextView.font = [UIFont systemFontOfSize:16];
            _displayTextView.backgroundColor = [UIColor clearColor];
            _displayTextView.scrollEnabled = NO;
            _displayTextView.editable = NO;
            _displayTextView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        }
        [self addSubview:_displayTextView];

    }
    return self;
}


@end
