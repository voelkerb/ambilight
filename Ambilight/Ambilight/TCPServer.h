//
//  TCPConnectionHandler.h
//  iHouse
//
//  Created by Benjamin Völker on 07/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "GCDAsyncSocket.h"
#import "BonjourServer.h"

// If a new Socket that was successfully discovered connected
extern NSString * const TCPServerNewSocketDiscovered;
extern NSString * const TCPServerNewMsgReceived;

@interface TCPServer : NSObject<GCDAsyncSocketDelegate> {
  dispatch_queue_t socketQueue;
  // The server socket
  GCDAsyncSocket *listenSocket;
  // All connected sockets
  NSMutableArray *connectedSockets;
  // If the server started
  BOOL started;
  // If the server is currently discovering for devices
  BOOL discovering;
  // The expected command that is received while discovering
  NSString *expectedReceiveCommand;
}

// Broadcast service server
//@property (nonatomic, strong) BonjourServer *bonjour;

// This class is singletone
+ (id)sharedTCPServer;
// Returns if the server is currently running
- (BOOL)isRunning;
// Start server
- (BOOL)startServer;
// Stop tcp server
- (void)stopServer;
// Returns a socket for a given hostname if it exist
- (GCDAsyncSocket*)getSocketWithHost:(NSString*)theHost;
- (BOOL)sendCommand:(NSString*) theCommand;

@end
