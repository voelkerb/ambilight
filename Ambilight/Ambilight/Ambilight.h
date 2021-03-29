//
//  Ambilight.h
//  LivingHome
//
//  Created by Benjamin Völker on 17.05.13.
//
//

#import <Foundation/Foundation.h>
#include "Screen.h"

@interface Ambilight : NSObject {
    CGImageRef cgimage;
    CGDataProviderRef provider;
    CVDisplayLinkRef displayLink;
    
}
@property (nonatomic, strong) Screen *currentScreen;
@property (nonatomic, strong) NSMutableArray* displays;
@property (nonatomic, assign) CGFloat bright;
@property (nonatomic, strong) NSColor* currentColor;
@property (nonatomic, unsafe_unretained) NSTimer *sampleTimer;
@property (nonatomic, assign) CGFloat red_adjust, green_adjust, blue_adjust, frame_adjust,
border_adjust;
@property (nonatomic, assign) BOOL sixteenToNine;
@property (nonatomic, assign) int serialFileDescriptor;
@property (nonatomic, assign) int offset;
@property (nonatomic, assign) float timerSpeed;
@property (nonatomic, assign) BOOL isCapturing;


- (id)init:(int) numberOfLEDs :(int) widthLEDs :(int) heightLEDs;
- (void) writeColors;
- (void) writeColorSafe:(NSColor*)color;
- (void) writeColor:(NSColor*)color;
- (void) writeByte: (char) val;
- (void) sampleScreen;
- (void) startCapturing;
- (void) stopCapturing;
- (void) startPattern:(int)pattern;
- (void) makeBlack;


@end



//static CVReturn DisplayLinkCallback (
//                              CVDisplayLinkRef displayLink,
//                              const CVTimeStamp *inNow,
//                              const CVTimeStamp *inOutputTime,
//                              CVOptionFlags flagsIn,
//                              CVOptionFlags *flagsOut,
//                              void *displayLinkContext);
