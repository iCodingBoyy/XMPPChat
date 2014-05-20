//
//  audiotest.h
//  libtest
//
//  Created by guanhaifeng on 11-7-31.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

//#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <AudioToolbox/AudioToolbox.h>
#import "CAStreamBasicDescription.h"
#import "aurio_helper.h"

@interface audiotest : UIViewController {
    AudioUnit					rioUnit;
	BOOL						unitIsRunning;
	BOOL						unitHasBeenCreated;
    
    
	BOOL						mute;
	
	DCRejectionFilter*			dcFilter;
	CAStreamBasicDescription	thruFormat;
	Float64						hwSampleRate;
    
    
	AURenderCallbackStruct		inputProc;
    
	SystemSoundID				buttonPressSound;
	
    NSString* timeresult;
    NSTimer *sendtimer;
    NSTimer *receivetimer;
    BOOL status;
    
    float theta;

}

@property (nonatomic, assign)	AudioUnit				rioUnit;
@property (nonatomic, assign)	BOOL						unitIsRunning;
@property (nonatomic, assign)	BOOL						unitHasBeenCreated;
@property (nonatomic, assign)	BOOL					mute;
@property (nonatomic, assign)	AURenderCallbackStruct	inputProc;
@property (nonatomic, retain)	NSTimer *timer;
@property (nonatomic, retain)	NSTimer *receivetimer;
@property (nonatomic, assign)	BOOL					status;




-(void) showresult:(int) flag;
-(void) sendtimerfunc;
-(void) sendconduct;
-(void) processconduct;
-(void) receivetimerfunc;
-(void) receiveprocessconduct;
-(void) receiveconduct;
-(void) stop;
-(void) audioswitch;
-(int) inputparse:(NSString *) datastr;

-(void) Swipeinitialization;
-(NSString *) Swipedetect;
-(BOOL) Swipereaddata:(uint8_t *) data connector:(uint8_t*)ctype;
-(int) Parsedata:(NSString*)inputdata;
-(void) Writeciphercode;
-(int) Checkheadphonestatus;
-(void) recharge:(int)times;
-(void) Poweron;
-(void) PowerOff;
-(BOOL) Powerstatus;
-(BOOL) Clearbuffer;

@end
