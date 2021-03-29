//
//  Ambilight.h
//  LivingHome
//
//  Created by Benjamin Völker on 17.05.13.
//
//

#import <Cocoa/Cocoa.h>

#include "Ambilight.h"
#include "SerialPort.h"
//#include "BonjourServer.h"
#include "TCPServer.h"


@interface AmbilightAppDelegate : NSObject <NSApplicationDelegate, BonjourServerDelegate> {
@private
  NSNetService	*netService;
  NSFileHandle	*listeningSocket;
  bool			serviceStarted;
  
  IBOutlet NSMenu *statusMenu;
  NSStatusItem *statusItem;
  IBOutlet NSMenuItem *captureMenuItem;
  IBOutlet NSMenuItem *manualMenuItem;
  IBOutlet NSMenuItem *startupMenuItem;
  __weak IBOutlet NSMenuItem *gradientMenuItem;
  IBOutlet NSMenuItem *fadeMenuItem;
    __weak IBOutlet NSMenuItem *confettiMenuItem;
    __weak IBOutlet NSMenuItem *rainbowMenuItem;
    __weak IBOutlet NSMenuItem *sinelonMenuItem;
    __weak IBOutlet NSMenuItem *juggleMenuItem;
    __weak IBOutlet NSMenuItem *bpmMenuItem;
    
  
  IBOutlet NSSlider *brightness;
  IBOutlet NSSlider *timeOffset;
  
  IBOutlet NSSlider *red_adjust;
  IBOutlet NSSlider *green_adjust;
  IBOutlet NSSlider *blue_adjust;
  IBOutlet NSSlider *frame_adjust;
  IBOutlet NSSlider *__unsafe_unretained border_adjust;
  IBOutlet NSSlider *__unsafe_unretained fade_adjust;
  
  IBOutlet NSTextField *__unsafe_unretained testOutput;
  
  NSSegmentedControl* chooseScreenControl;
  int ambilightSerialFileDescriptor;
  int lightSerialFileDescriptor;
  
}

@property (nonatomic, strong) Ambilight *ambilight;
@property (nonatomic, strong) SerialPort *ambilightSerialPort;
@property (nonatomic, strong) SerialPort *lightSerialPort;
@property (nonatomic, strong) BonjourServer *server;
@property (nonatomic, strong) TCPServer *tcpServer;
@property (nonatomic, strong) IBOutlet NSSegmentedControl* chooseScreenControl;
@property (strong) IBOutlet NSSlider *brightness;
@property (strong) IBOutlet NSSlider *timeOffset;
@property (strong) IBOutlet NSSlider *red_adjust;
@property (strong) IBOutlet NSSlider *green_adjust;
@property (strong) IBOutlet NSSlider *blue_adjust;
@property (strong) IBOutlet NSSlider *frame_adjust;
@property (unsafe_unretained) IBOutlet NSSlider *border_adjust;
@property (unsafe_unretained) IBOutlet NSSlider *fade_adjust;
@property (unsafe_unretained) IBOutlet NSTextField *testOutput;

- (IBAction)startCapturing:(id)sender;
- (IBAction)startFading:(id)sender;
- (IBAction)openColorPicker:(id)sender;
- (IBAction)closeApp:(id)sender;
- (IBAction)toggleLaunchAtStartup:(id)sender;
- (LSSharedFileListItemRef)itemRefInLoginItems;
- (BOOL)isLaunchAtStartup;
- (void) colorPicked:(NSColorWell *) picker;

@end
