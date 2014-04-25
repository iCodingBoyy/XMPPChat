//
//  YZChatToolBoxView.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-2.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^ClickBtnBlock)(NSInteger buttonTag);

@interface YZChatToolBoxView : UIScrollView
@property (nonatomic, copy) ClickBtnBlock btnBlock;
- (id)initWithFrame:(CGRect)frame  block:(ClickBtnBlock)block;
@end
