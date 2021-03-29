//
//  SerialPort.h
//  LivingHome
//
//  Created by Benjamin Völker on 17.05.13.
//
//

#import <Foundation/Foundation.h>
// import IOKit headers
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#include <IOKit/serial/ioss.h>
#include <sys/ioctl.h>

@interface SerialPort : NSObject {
    NSString *selectedSerialPort;
    NSMutableArray *serialPortList;
	struct termios gOriginalTTYAttrs;
}
@property (nonatomic, assign) int serialFileDescriptor;

- (NSString *) searchForArduino;
- (NSString *) searchFor:(NSString *)deviceNameOrSubname;
- (NSString *) openSerialPort: (NSString *)serialPortFile baud: (speed_t)baudRate;
- (void) loadSerialPortList;
@end
