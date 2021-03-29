//
//  Ambilight.h
//  LivingHome
//
//  Created by Benjamin Völker on 17.05.13.
//
//

#import "AmbilightAppDelegate.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

//#define SERVICE_NAME	@"iPhone Sync Service"
// This will send data to any device matchin the name. so all other usbmodems connected to the computer might receive the data
#define AMBILIGHT_DEVICE_NAME @"usbmodem"
#define SERIAL_BAUDRATE 4000000
//#define AMBILIGHT_DEVICE_NAME @"usbserial"
//#define LIGHT_DEVICE_NAME @"LIGHT_LIVING_ROOM"
#define NUMB_OF_LEDs 460
#define NUMB_OF_LEDs_WIDTH 144
#define NUMB_OF_LEDs_HEIGHT 86

#define ColorFromHEX(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

@implementation AmbilightAppDelegate
@synthesize border_adjust;
@synthesize fade_adjust;
@synthesize testOutput;
@synthesize brightness, timeOffset, chooseScreenControl;
@synthesize red_adjust, blue_adjust, green_adjust, frame_adjust;
@synthesize ambilight, ambilightSerialPort, lightSerialPort, server, tcpServer;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
}

-(void)awakeFromNib{
  // Set the status bar icon
  statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
  [statusItem setMenu:statusMenu];
  [statusItem setImage:[NSImage imageNamed:@"icon_16x16@2x"]];
  [statusItem setHighlightMode:YES];
  // Set the state of isLauncat startup depending on the stored settings
  [startupMenuItem setState:[self isLaunchAtStartup]];
  
  // IÍnit ambilight Sefrialport connection
  ambilightSerialPort = [[SerialPort alloc] init];
  NSString *ambilightName = [ambilightSerialPort searchFor:AMBILIGHT_DEVICE_NAME];
  [ambilightSerialPort openSerialPort:ambilightName baud:SERIAL_BAUDRATE];
  ambilightSerialFileDescriptor = [ambilightSerialPort serialFileDescriptor];
  
  // Start bonjour server so that the ambilight service can be found in the network
  // Bonjour server data: See standalone ambilight iOS app
  // server = [[BonjourServer alloc] init];
  // We want to receive bonjour/TCP messages
  // server.delegate = self;
  // [server startServer];
  // Receive TCP data from e.g. Homebridge so that ambilight can be controled over homekit
  tcpServer = [TCPServer sharedTCPServer];
  [tcpServer startServer];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(remoteMsg:) name:TCPServerNewMsgReceived object:nil];
  // Init ambilight with the number of leds
  ambilight = [[Ambilight alloc] init:NUMB_OF_LEDs:NUMB_OF_LEDs_WIDTH:NUMB_OF_LEDs_HEIGHT];
  // Set user default values and serialfile descriptor
  [self setAmbilightValues:self];
  // Set the serialport  so that the ambilight object can write to it
  [ambilight setSerialFileDescriptor:ambilightSerialFileDescriptor];
}


- (IBAction)setAmbilightValues:(id)sender {
  [ambilight setRed_adjust:[red_adjust floatValue]];
  [ambilight setGreen_adjust:[green_adjust floatValue]];
  [ambilight setBlue_adjust:[blue_adjust floatValue]];
  [ambilight setBorder_adjust:[border_adjust floatValue]];
  [ambilight setFrame_adjust:[frame_adjust floatValue]];
  [ambilight setTimerSpeed:[fade_adjust maxValue] + 0.02f - [fade_adjust floatValue]];
  [ambilight setBright:[brightness floatValue]];
  [ambilight setOffset:[timeOffset intValue]];
}

-(IBAction)closeApp:(id)sender{
  // Add a delay to ensure that it terminates at the top of the next pass through the event loop
  [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

- (IBAction)startCapturing:(id)sender {
  if ([captureMenuItem state] == YES) {
    [ambilight stopCapturing];
    // And set black
    [ambilight makeBlack];
    [self makeMenuRight:nil];
  } else {
    [self makeMenuRight:captureMenuItem];
    [fadeMenuItem setState:false];
    [ambilight startCapturing];
  }
}
- (IBAction)startBPM:(id)sender {
    if ([bpmMenuItem state] == YES) {
        [self makeMenuRight:nil];
        [ambilight makeBlack];
    } else {
        [self makeMenuRight:bpmMenuItem];
        [ambilight stopCapturing];
        [ambilight startPattern:8];
    }
}

- (IBAction)startJuggle:(id)sender {
    if ([juggleMenuItem state] == YES) {
        [self makeMenuRight:nil];
        [ambilight makeBlack];
    } else {
        [self makeMenuRight:juggleMenuItem];
        [ambilight stopCapturing];
        [ambilight startPattern:7];
    }
}
- (IBAction)startSinelon:(id)sender {
    if ([sinelonMenuItem state] == YES) {
        [self makeMenuRight:nil];
        [ambilight makeBlack];
    } else {
        [self makeMenuRight:sinelonMenuItem];
        [ambilight stopCapturing];
        [ambilight startPattern:6];
    }
}

- (IBAction)startConfetti:(id)sender {
    if ([confettiMenuItem state] == YES) {
        [self makeMenuRight:nil];
        [ambilight makeBlack];
    } else {
        [self makeMenuRight:confettiMenuItem];
        [ambilight stopCapturing];
        [ambilight startPattern:5];
    }
}

- (IBAction)startGradient:(id)sender {
  if ([gradientMenuItem state] == YES) {
    [self makeMenuRight:nil];
    [ambilight makeBlack];
  } else {
    [self makeMenuRight:gradientMenuItem];
    [ambilight stopCapturing];
    [ambilight startPattern:2];
  }
}

- (IBAction)startRainbow:(id)sender {
    if ([rainbowMenuItem state] == YES) {
        [self makeMenuRight:nil];
        [ambilight makeBlack];
    } else {
        [self makeMenuRight:rainbowMenuItem];
        [ambilight stopCapturing];
        [ambilight startPattern:3];
    }
}

- (IBAction)startFading:(id)sender {
  if ([fadeMenuItem state] == YES) {
    [ambilight makeBlack];
    [self makeMenuRight:nil];
  } else {
    [self makeMenuRight:fadeMenuItem];
    [ambilight stopCapturing];
    [ambilight startPattern:1];
  }
}

- (void)makeMenuRight:(NSMenuItem*)menuItem {
  [captureMenuItem setState:NSOffState];
  [juggleMenuItem setState:NSOffState];
  [bpmMenuItem setState:NSOffState];
  [sinelonMenuItem setState:NSOffState];
  [confettiMenuItem setState:NSOffState];
  [rainbowMenuItem setState:NSOffState];
  [fadeMenuItem setState:NSOffState];
  [gradientMenuItem setState:NSOffState];
  [menuItem setState:NSOnState];
}


- (IBAction) openColorPicker:(id)sender {
  [ambilight stopCapturing];
  [self makeMenuRight:nil];
  [NSApp activateIgnoringOtherApps:YES];
  [[NSColorPanel sharedColorPanel] setTarget:self];
  [[NSColorPanel sharedColorPanel] setAction:@selector(colorPicked:)];
  [[NSColorPanel sharedColorPanel] makeKeyAndOrderFront:nil];
}

- (void) colorPicked: (NSColorWell *) picker{
  [ambilight writeColorSafe:picker.color];
}


- (void)remoteMsg:(NSNotification*)notification {
  
  NSString *body = @"123456";
  NSString *head = @"HTTP/1.1 200 OK\r\nServer: WebServer\r\nContent-Type: text/html\r\nContent-Length: 6\r\nConnection: close\r\n\r\n";
  NSString *msg = [notification object];
  if (msg) {
    NSLog(@"Decoding remote msg...");
    NSRange range = [msg rangeOfString:@"a"];
    NSLog(@"a at loc %lu", (unsigned long)range.location);
    if (range.location == 0) {
      bool value = [[msg substringFromIndex:range.location+range.length] boolValue];
      if (value) {
        NSLog(@"Start ambilight");
        if(ambilight.isCapturing == false) {
          [ambilight startCapturing];
          [self makeMenuRight:captureMenuItem];
        }
      } else {
        [ambilight stopCapturing];
        [self makeMenuRight:nil];
        [self performSelector:@selector(makeBlack) withObject:nil afterDelay:0.1];
        NSLog(@"Stop ambilight");
      }
      [[TCPServer sharedTCPServer] sendCommand:[NSString stringWithFormat:@"%@%@", head, body]];
    }
    range = [msg rangeOfString:@"f"];
    if (range.location == 0) {
      bool value = [[msg substringFromIndex:range.location+range.length] boolValue];
      if (value) {
        [ambilight stopCapturing];
        [ambilight startPattern:1];
        [self makeMenuRight:fadeMenuItem];
        NSLog(@"Start fading");
      } else {
        [ambilight makeBlack];
        [self makeMenuRight:nil];
        NSLog(@"Stop fading");
      }
    }
    range = [msg rangeOfString:@"b"];
    if (range.location == 0) {
      float value = [[msg substringFromIndex:range.location+range.length] floatValue];
      if (value >= 0 && value < 1.0) {
        [ambilight setBright:value];
        NSLog(@"Set brightness to: %f", value);
      } else {
        NSLog(@"Brightness does not match: %f", value);
      }
      [[TCPServer sharedTCPServer] sendCommand:[NSString stringWithFormat:@"%@%@", head, body]];
    }
    range = [msg rangeOfString:@"c"];
    if (range.location == 0) {
      int r = [[msg substringFromIndex:range.location+range.length] intValue];
      range = [msg rangeOfString:@";"];
      int g = [[msg substringFromIndex:range.location+range.length] intValue];
      msg = [msg substringFromIndex:range.location+range.length];
      range = [msg rangeOfString:@";"];
      int b = [[msg substringFromIndex:range.location+range.length] intValue];
      NSLog(@"R:%i,G:%i,B:%i", r, g, b);
      NSColor *color = [NSColor colorWithSRGBRed:(r/255.0) green:(g/255.0) blue:(b/255.0f) alpha:1.0f];
        if (ambilight.isCapturing) {
            [ambilight stopCapturing];
            [ambilight performSelector:@selector(writeColorSafe:) withObject:color afterDelay:0.2];
        } else {
            [ambilight writeColorSafe:color];
        }
      [[TCPServer sharedTCPServer] sendCommand:[NSString stringWithFormat:@"%@%@", head, body]];
    }
    range = [msg rangeOfString:@"h0x"];
    NSLog(@"Heurika");
    if (range.location == 0) {
      NSString *hex = [msg substringFromIndex:range.location+range.length];
      const char *cStr = [hex cStringUsingEncoding:NSASCIIStringEncoding];
      NSLog(@"%s", cStr);
      long col = strtol(cStr, NULL, 16);
      unsigned char r, g, b;
      b = col & 0xFF;
      g = (col >> 8) & 0xFF;
      r = (col >> 16) & 0xFF;
      NSLog(@"R:%i,G:%i,B:%i", r, g, b);
      NSColor *color = [NSColor colorWithRed:(float)r/255.0f green:(float)g/255.0f blue:(float)b/255.0f alpha:1];
        if (ambilight.isCapturing) {
            [ambilight stopCapturing];
            [ambilight performSelector:@selector(writeColorSafe:) withObject:color afterDelay:0.2];
        } else {
            [ambilight writeColorSafe:color];
        }
      [[TCPServer sharedTCPServer] sendCommand:[NSString stringWithFormat:@"%@%@", head, body]];
    }
    range = [msg rangeOfString:@"h?"];
    if (range.location != NSNotFound) {
      NSColor *color = [ambilight currentColor];
      unsigned char r, g, b;
      r = (uint8_t)([color redComponent]*255);
      g = (uint8_t)([color greenComponent]*255);
      b = (uint8_t)([color blueComponent]*255);
      NSLog(@"R:%i,G:%i,B:%i", r, g, b);
//      NSString *hex = [NSString stringWithFormat:@"%02x%02x%02x",r, g, b];
      [[TCPServer sharedTCPServer] sendCommand:[NSString stringWithFormat:@"%@%02x%02x%02x", head, r, g, b]];
      //[[TCPServer sharedTCPServer] sendCommand:hex];
    }
  }
}
  
  
- (void)connectionReceived:(NSDictionary *)dict {
  NSLog(@"We received: %@", dict);
  NSColor *color = [NSColor colorWithSRGBRed:([[dict objectForKey:@"red"] intValue]/255.0) green:([[dict objectForKey:@"green"] intValue]/255.0) blue:([[dict objectForKey:@"blue"] intValue]/255.0f) alpha:1.0f];

  NSString *str = [NSString stringWithFormat:@"r: %i, g: %i, b: %i",(int)([color redComponent]*255), (int)([color greenComponent]*255), (int)([color blueComponent]*255)];
  [testOutput setStringValue:str];

  [ambilight setBright:[[dict objectForKey:@"brightness"] floatValue]];
  NSNumber *capturing = [dict objectForKey:@"capturing"];
  NSNumber *fading = [dict objectForKey:@"fading"];


  if ([capturing isEqualToNumber:[NSNumber numberWithInt:1]]) {
      if(ambilight.isCapturing == false) {
          [ambilight startCapturing];
          [self makeMenuRight:captureMenuItem];
      }
  } else if ([fading isEqualToNumber:[NSNumber numberWithInt:1]]) {
      [ambilight startPattern:1];
      [self makeMenuRight:fadeMenuItem];
  } else {
      [ambilight stopCapturing];
      [ambilight makeBlack];
      [self makeMenuRight:nil];
      [ambilight writeColor:color];
  }
}


- (BOOL)isLaunchAtStartup {
    // See if the app is currently in LoginItems.
    LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
    // Store away that boolean.
    BOOL isInList = itemRef != nil;
    // Release the reference if it exists.
    if (itemRef != nil) CFRelease(itemRef);
    
    return isInList;
}


- (IBAction)toggleLaunchAtStartup:(id)sender {
    // Toggle the state.
    BOOL shouldBeToggled = ![self isLaunchAtStartup];
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return;
    if (shouldBeToggled) {
        // Add the app to the LoginItems list.
        CFURLRef appUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
        if (itemRef) CFRelease(itemRef);
    }
    else {
        // Remove the app from the LoginItems list.
        LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
        LSSharedFileListItemRemove(loginItemsRef,itemRef);
        if (itemRef != nil) CFRelease(itemRef);
    }
    CFRelease(loginItemsRef);
    [sender setState:shouldBeToggled];
}



- (LSSharedFileListItemRef)itemRefInLoginItems {
    LSSharedFileListItemRef itemRef = nil;

    NSURL *itemUrl = nil;

    CFURLRef cfURL = CGPDFDocumentCreateWithURL((__bridge CFURLRef)itemUrl);

    // Get the app's URL.
    NSURL *appUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return nil;
    // Iterate over the LoginItems.
    NSArray *loginItems = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItemsRef, nil);
    for (int currentIndex = 0; currentIndex < [loginItems count]; currentIndex++) {
        // Get the current LoginItem and resolve its URL.
        LSSharedFileListItemRef currentItemRef = (__bridge LSSharedFileListItemRef)[loginItems objectAtIndex:currentIndex];
        if (LSSharedFileListItemResolve(currentItemRef, 0, &cfURL, NULL) == noErr) {
            // Compare the URLs for the current LoginItem and the app.
            if ([(__bridge NSURL *)cfURL isEqual:appUrl]) {
                // Save the LoginItem reference.
                itemRef = currentItemRef;
            }
        }
    }
    // Retain the LoginItem reference.
    if (itemRef != nil) CFRetain(itemRef);
    CFRelease(loginItemsRef);

    return itemRef;
}




@end
