//
//  Ambilight.m
//  LivingHome
//
//  Created by Benjamin Völker on 17.05.13.
//
//

#import "Ambilight.h"
#define MAX_OFFSET 10
#define MAX_LEDs 500
#define RED 0
#define GREEN 1
#define BLUE 2
// The offset (distance between to sampled pixels)
// Decreasing this, will have impact on the processor
#define scanOffset 10
#define CylonDarkener 0.2

@interface Ambilight () {
  int fadeColor;
  int fadeRed;
  int fadeBlue;
  int fadeGreen;
  int cylonLED[3];
  int NUMB_LEDS;
  uint8_t colorInfo[MAX_OFFSET][MAX_LEDs][3];
  int oneCapture[MAX_LEDs][3];
  // Number of LED's at Top and Bottom
  int LEDCountWidth;
  // Number of LED's at sides
  int LEDCountHeight;
  int offsetIndexNew;
  int offsetIndexOld;
  NSColor* goalColor;
}
@end

@implementation Ambilight
@synthesize sampleTimer;
@synthesize red_adjust, blue_adjust, green_adjust, border_adjust, frame_adjust;
@synthesize currentScreen, displays;
@synthesize serialFileDescriptor;
@synthesize timerSpeed;
@synthesize currentColor;
@synthesize isCapturing;
@synthesize bright, offset;
@synthesize sixteenToNine;


- (id)init:(int) numberOfLEDs :(int) widthLEDs :(int) heightLEDs {
    self = [super init];
    if (self) {
      // Init screen object
      [self initScreen];
      
      goalColor = NSColor.blackColor;
      // init variable default
      red_adjust = blue_adjust = green_adjust = border_adjust = frame_adjust = 1.0;
      bright = 1.0;
      timerSpeed = 0.1;
      NUMB_LEDS = numberOfLEDs;
      LEDCountHeight = heightLEDs;
      LEDCountWidth = widthLEDs;
      currentColor = [NSColor purpleColor];
      cylonLED[0] = 0;
      cylonLED[1] = 1;
      cylonLED[2] = 2;
      sixteenToNine = false;
      fadeColor = 1;
      fadeBlue = fadeGreen = 0;
      fadeRed = 255;
      offset = 0;
      offsetIndexNew = 0;
      offsetIndexOld = 0;
      for (int i = 0; i < MAX_OFFSET; i++) {
        for (int j = 0; j < MAX_LEDs; j++) {
          colorInfo[i][j][0] = 0;
          colorInfo[i][j][1] = 0;
          colorInfo[i][j][2] = 0;
        }
      }
    }
    return self;
}

- (void) setBright:(CGFloat)bright {
    bright = bright;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"%i", (int)(255*bright));
        [self writeByte:0x62];
        [self writeByte:(int)(255*bright)];
        [self writeByte:0x0d];
        [self writeByte:0x0a];
    });
    
}

- (void)initScreen {
  // init displays to sample
  CGDirectDisplayID ids[3];
  CGDisplayCount count = 0;
  CGGetOnlineDisplayList(3, ids, &count);
  
  
  displays = [NSMutableArray array];
  for (int i=0; i<count; i++) {
    Screen *newScreen = [[Screen alloc] init];
    newScreen.displayId = ids[i];
    newScreen.resolution = CGSizeMake(CGDisplayPixelsWide(ids[i]), CGDisplayPixelsHigh(ids[i]));
    [self.displays addObject: newScreen];
  }
  // set current display
  self.currentScreen = [self.displays objectAtIndex:0];
}

static CVReturn DisplayLinkCallback (
                              CVDisplayLinkRef displayLink,
                              const CVTimeStamp *inNow,
                              const CVTimeStamp *inOutputTime,
                              CVOptionFlags flagsIn,
                              CVOptionFlags *flagsOut,
                              void *displayLinkContext)
{
    @autoreleasepool {
        [(__bridge Ambilight*) displayLinkContext sampleScreen];
    }
    return YES;
}
bool occupied = false;

- (void) resetOccupied2 {
  [self writeColor:goalColor];
  occupied = false;
}

- (void) resetOccupied {
  occupied = false;
}

- (void) writeColorsSafe {
    if (occupied == true) return;
    occupied = true;
    [self writeColors];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(resetOccupied) withObject:nil afterDelay:0.04];
    });
}

- (void) writeColorSafe:(NSColor*) color {
  goalColor = color;
  if (occupied == true) return;
  occupied = true;
    dispatch_async(dispatch_get_main_queue(), ^{
  [self performSelector:@selector(resetOccupied2) withObject:nil afterDelay:0.05];
    });
}

- (void) writeColor:(NSColor*) color {
	currentColor = color;
    
  uint8_t red = (uint8_t)((float)([color redComponent]*255.0));
	uint8_t green = (uint8_t)((float)([color greenComponent]*255));
	uint8_t blue = (uint8_t)((float)([color blueComponent]*255));
  
  NSLog(@"Write color: %i:%i:%i", red, green, blue);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [self writeByte:0x63];
      [self writeByte:red];
      [self writeByte:green];
      [self writeByte:blue];
      [self writeByte:0x0d];
      [self writeByte:0x0a];
    });
}

- (void) writeColors {
  // This is 's'
  [self writeByte:0x73];
	char val[3*NUMB_LEDS];
	int i = 0;
	for (int j = 0; j < 3*NUMB_LEDS; j=j+3) {
		val[j] = colorInfo[offsetIndexOld][i][RED]*bright*red_adjust;
		val[j+1] = colorInfo[offsetIndexOld][i][GREEN]*bright*green_adjust;
		val[j+2] = colorInfo[offsetIndexOld][i][BLUE]*bright*blue_adjust;
		i++;
	}
	[self writeALL:val];
	// Finishing // Writing crap
	[self writeByte:0xff];
	[self writeByte:0xff];
	[self writeByte:0xff];
}


- (void) writeALL : (char[]) val {
	if(serialFileDescriptor!=-1) {
		write(serialFileDescriptor, (const void *) val, 3*NUMB_LEDS);
	} else {
		//NSLog(@"Tried to write byte but no ambilight device found");
	}
}

- (void) write3Bytes : (char[3]) val {
	if(serialFileDescriptor!=-1) {
		write(serialFileDescriptor, (const void *) val, 3);
	} else {
		//NSLog(@"Tried to write byte but no ambilight device found");
	}
}

- (void) writeByte: (char) val {
    if(serialFileDescriptor!=-1) {
		write(serialFileDescriptor, &val, 1);
	} else {
		//NSLog(@"Tried to write byte but no ambilight device found");
	}
}

- (void) startCapturing {
    isCapturing = true;
    CVReturn error = kCVReturnSuccess;
    CGDirectDisplayID displayID = CGMainDisplayID();
    
    error = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
    if(error) {
        NSLog(@"DisplayLink returned error:%d", error);
        displayLink = NULL;
    }
    error = CVDisplayLinkSetOutputCallback(displayLink, &DisplayLinkCallback, (__bridge void *)self);
    if(error) {
        NSLog(@"DisplayLink callback creation failed:%d", error);
        displayLink = NULL;
    }
    if (displayLink){
        CVDisplayLinkStart(displayLink);
    }
}

- (void)stopCapturing {
  isCapturing = false;
  CVDisplayLinkStop(displayLink);
  if (sampleTimer) {
    [sampleTimer invalidate];
    sampleTimer = nil;
  }
  [self makeBlack];
}

- (void) startPattern:(int)pattern {
  [self writeByte:0x70];
  [self writeByte:pattern];
}

- (void) makeBlack {
    [self writeByte:0x6f];
}

- (int)conformRGB: (int)component {
    int tmpComponent = component;
    if (tmpComponent < 0) tmpComponent = 0;
    else if (tmpComponent > 255) tmpComponent = 255;
    return tmpComponent;
}


- (void)sampleScreen {
  // If current screen object was destroyed
  if (currentScreen == nil) {
    [self initScreen];
    // If it is still not reachable, simply return
    if (currentScreen == nil) {
      [self stopCapturing];
      return;
    }
  }
  
    CGSize frameSize = CGSizeMake(currentScreen.resolution.width*frame_adjust, currentScreen.resolution.height*frame_adjust);
    
	
    cgimage = CGDisplayCreateImageForRect(currentScreen.displayId, CGRectMake(0, 0, currentScreen.resolution.width, currentScreen.resolution.height));
    
    size_t width  = CGImageGetWidth(cgimage);
    size_t height = CGImageGetHeight(cgimage);
    
    size_t bpr = CGImageGetBytesPerRow(cgimage);
    size_t bpp = CGImageGetBitsPerPixel(cgimage);
    size_t bpc = CGImageGetBitsPerComponent(cgimage);
    size_t bytes_per_pixel = bpp / bpc;
    
    
    
    provider = CGImageGetDataProvider(cgimage);
    NSData* data = (id)CFBridgingRelease(CGDataProviderCopyData(provider));
    
    
    const uint8_t* bytes = [data bytes];
	
	// Integer that stores the color value for RGB in once
    const uint8_t* pixel;
	
	
	
	// Integer that stores the pixels sampled for one LED
	int count = 1;
	// The width of the area of one LED is stored in this integers
	int topBottomStep = (int)width/LEDCountWidth;
	int leftRightStep = (int)height/LEDCountHeight;
	// The offsets in the color array (top,right,bottom,left)
	int topOffset = 0;
	int rightOffset = LEDCountWidth;
	int bottomOffset = LEDCountWidth + LEDCountHeight;
	int leftOffset = 2*LEDCountWidth + LEDCountHeight;
	
	int topStart = 0;
  // Reset values
  for (int i = 0; i < MAX_LEDs; i++) {
    oneCapture[i][0] = 0;
    oneCapture[i][1] = 0;
    oneCapture[i][2] = 0;
  }
  

  int topCapture[3] = {0,0,0};
 
  
  // Try to figure out if picture is 21:9 format
  // If so, do not cover the top and bottm
  // Just a rough sample here over firs 40 pixel
  for (int y=0; y < 40; y+= frameSize.height) {
    for (int x=0; x < width; x+= frameSize.width) {
      pixel = &bytes[y * bpr + x * bytes_per_pixel];
    
      // And add to array
      topCapture[RED] += pixel[2]; //Red
      topCapture[GREEN] += pixel[1];  //Green
      topCapture[BLUE] += pixel[0];       //Blue
        
      count++;
    }
  }
  // This here is not neccessary since we check for everything black
  topCapture[RED] /= count;
  topCapture[GREEN] /= count;
  topCapture[BLUE] /= count;
  
  count = 1;
  if ((topCapture[RED] + topCapture[GREEN] + topCapture[BLUE]) < 5)  {
    sixteenToNine = true;
  } else {
    sixteenToNine = false;
  }
  
	if (sixteenToNine) {
		topStart = (int)((height - width * 9/21)/2.0f);
		//bottomEnd = height - topStart;
		//NSLog(@"%zu, %lu: %i",height, width * 9/16, topStart);
	}

	
	//TOP
	for (int i = 0; i < LEDCountWidth; i++) {
    int index = i + topOffset;
		for (int y=topStart; y < height*border_adjust + topStart; y=y+frameSize.height) {
			for (int x=(i)*topBottomStep; x < (i+1)*topBottomStep; x=x+frameSize.width) {
				pixel = &bytes[y * bpr + x * bytes_per_pixel];
			
				// And add to array
				oneCapture[index][RED] += pixel[2]; //Red
				oneCapture[index][GREEN] += pixel[1];  //Green
				oneCapture[index][BLUE] += pixel[0];       //Blue
			
				count++;
			}
		}
		// And calculate the mean for every Color of the LED
		oneCapture[index][RED] /= count;
		oneCapture[index][GREEN] /= count;
    oneCapture[index][BLUE] /= count;
    
		count = 1;
	}
	
	
	// RIGHT
  for (int i = 0; i < LEDCountHeight; i++) {
    int index = i + rightOffset;
		for (int y = (i)*leftRightStep; y < (i+1)*leftRightStep; y=y+frameSize.height) {
			for (int x=width*(1.0 - border_adjust); x < width; x=x+frameSize.width) {
				pixel = &bytes[y * bpr + x * bytes_per_pixel];
			
				// And add to array
				oneCapture[index][RED] += pixel[2]; //Red
				oneCapture[index][GREEN] += pixel[1];  //Green
				oneCapture[index][BLUE] += pixel[0];       //Blue
				
				count++;
			}
		}
		// And calculate the mean for every Color of the LED
		oneCapture[index][RED] /= count;
		oneCapture[index][GREEN] /= count;
		oneCapture[index][BLUE] /= count;
		count = 1;
	}
	
	
	
	// BOTTOM
  for (int i = LEDCountWidth - 1; i >= 0; i--) {
    int index = LEDCountWidth - 1 - i + bottomOffset;
		for (size_t y=height*(1.0 - border_adjust)- topStart; y < height-topStart; y=y+frameSize.height) {
			for (int x=(i)*topBottomStep; x < (i+1)*topBottomStep; x=x+frameSize.width) {
				pixel = &bytes[y * bpr + x * bytes_per_pixel];
			
        // And add to array
        oneCapture[index][RED] += pixel[2]; //Red
        oneCapture[index][GREEN] += pixel[1];  //Green
        oneCapture[index][BLUE] += pixel[0];       //Blue
        count++;
			}
		}
    
    oneCapture[index][RED] /= count;
    oneCapture[index][GREEN] /= count;
    oneCapture[index][BLUE] /= count;
    count = 1;
	}

	//NSLog(@"%f, %f, ", frameSize.height, frameSize.width);
	
	// LEFT
  for (int i = LEDCountHeight - 1; i >= 0; i--) {
    int index = LEDCountHeight - 1 - i + leftOffset;
    
		for (int y = (i)*leftRightStep; y < (i+1)*leftRightStep; y=y+frameSize.height) {
        	for (int x=0; x < width*border_adjust; x=x+frameSize.width) {
         	    pixel = &bytes[y * bpr + x * bytes_per_pixel];
				// And add to array
				
				 oneCapture[index][RED] += pixel[2]; //Red
				 oneCapture[index][GREEN] += pixel[1];  //Green
				 oneCapture[index][BLUE] += pixel[0];       //Blue
				count++;
			}
		}
		
    
    oneCapture[index][RED] /= count;
    oneCapture[index][GREEN] /= count;
    oneCapture[index][BLUE] /= count;

    count = 1;
		 
	}
				
	
  
  CGImageRelease(cgimage);
  
  for (int i = 0; i < NUMB_LEDS; i++) {
    colorInfo[offsetIndexNew][i][RED] = (uint8_t)oneCapture[i][RED];
    colorInfo[offsetIndexNew][i][GREEN] = (uint8_t)oneCapture[i][GREEN];
    colorInfo[offsetIndexNew][i][BLUE] = (uint8_t)oneCapture[i][BLUE];
  }
  
  
    //[self writeColors];
    [self writeColorsSafe];
  
  offsetIndexNew++;
  if (offsetIndexNew >= MAX_OFFSET) offsetIndexNew = 0;
  
  offsetIndexOld = offsetIndexNew - offset;
  if (offsetIndexOld < 0) offsetIndexOld += MAX_OFFSET;
  
}



@end
