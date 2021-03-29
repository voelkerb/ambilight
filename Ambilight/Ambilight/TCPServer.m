//
//  TCPConnectionHandler.m
//  iHouse
//
//  Created by Benjamin Völker on 07/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import "TCPServer.h"

#define DEBUG_TCP 1
#define DEBUG_DISCOVER 1
#define DISCOVERING_COMMAND @"?\n"
#define TCP_PORT 2001

NSString * const TCPServerNewSocketDiscovered = @"TCPServerNewSocketDiscovered";
NSString * const TCPServerNewMsgReceived = @"TCPServerNewMsgReceived";
GCDAsyncSocket *lastSocket = nil;

@implementation TCPServer
//@synthesize bonjour;

/*
 * Make this class singletone, so that it could be used from anywhere after init
 */
+ (id)sharedTCPServer {
  static TCPServer *sharedTCPServer = nil;
  @synchronized(self) {
    if (sharedTCPServer == nil) {
      sharedTCPServer = [[self alloc] init];
    }
  }
  return sharedTCPServer;
}


/*
 * Init funciton
 */
- (id)init {
  if((self = [super init])) {
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    started = false;
    // Setup an array to store all accepted client connections
    connectedSockets = [[NSMutableArray alloc] init];
//    // Start broadcast service
//    bonjour = [[BonjourServer alloc] init];
//    //bonjour.delegate = self;
//    [bonjour startServer];
  }
  return self;
}


/*
 * Start or stop the tcp server
 */
- (BOOL)startServer {
  if(started) {
    if (DEBUG_TCP) NSLog(@"Was running already");
    return true;
  }
  // Get desired port
  NSInteger port = TCP_PORT;
  // if port is beyond bounds return
  if (port < 0 || port > 65535) {
    if (DEBUG_TCP) NSLog(@"Port beyond tcp-port bounds");
    return false;
  }
  // Try to open port
  NSError *error = nil;
  if(![listenSocket acceptOnPort:port error:&error]) {
    // If open fails
    if (DEBUG_TCP) NSLog(@"Error starting server: %@", error);
    return false;
  }
  // If open succeeded
  if (DEBUG_TCP) NSLog(@"TCP server started on local port %hu", [listenSocket localPort]);
  started = true;
  return true;
}

- (void)stopServer {
  // Stop accepting connections
  [listenSocket disconnect];
  // Stop any client connections
  NSUInteger i;
  for (i = 0; i < [connectedSockets count]; i++) {
    @synchronized(connectedSockets){
      [[connectedSockets objectAtIndex:i] disconnect];
    }
  }
  if (DEBUG_TCP) NSLog(@"Stopped server");
  started = false;
}

/*
 * Returns if the tcp server is running
 */
- (BOOL)isRunning {
  return [listenSocket isConnected];
}


/*
 * Return a socket with the given hostname if exist
 */
-(GCDAsyncSocket *)getSocketWithHost:(NSString *)theHost {
  for (GCDAsyncSocket *theSocket in connectedSockets) {
    if ([[theSocket connectedHost] isEqualToString:theHost]) {
      return theSocket;
    }
  }
  return nil;
}
/*
 * Send data to the socket client, called from delegate.
 */
- (BOOL)sendCommand:(NSString*) theCommand {
  if (lastSocket == nil) return false;
  // Reset delegate to us, so that multiple connectioknHandlers can be used with one socket
  lastSocket.delegate = self;
  // Decode string into data and send it to all available socket connections
  NSData *data = [theCommand dataUsingEncoding:NSUTF8StringEncoding];
  // Send the decoded string as data to the socket
  [lastSocket writeData:data withTimeout:-1 tag:0];
  NSLog(@"Sent Successfull: %@", theCommand);
  return true;
}



#pragma mark Socket delegate functions
/*
 * If a new client is connected to the server.
 */
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
  // This method is executed on the socketQueue (not the main thread)
  @synchronized(connectedSockets) {
    [connectedSockets addObject:newSocket];
  }
  
  // Get ip and port
  NSString *host = [newSocket connectedHost];
  UInt16 port = [newSocket connectedPort];
  dispatch_async(dispatch_get_main_queue(), ^{
    @autoreleasepool {
      if (DEBUG_TCP) NSLog(@"Accepted client %@:%hu", host, port);
      // Add socket to all yet connected sockets
        [self->connectedSockets addObject:newSocket];
    }
  });
  
  // Let the socket be able to write data to us
  [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
  //[newSocket readDataToData:[GCDAsyncSocket CRData] withTimeout:-1 tag:0];
}

/*
 * If the socket did write data successfully, allow that data could be read again
 */
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
  // This method is executed on the socketQueue (not the main thread)
  [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
  if (DEBUG_DISCOVER) NSLog(@"Socket did write sth strange");
}

/*
 * Is called if data from a socket is read
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
  // This method is executed on the socketQueue (not the main thread)
  dispatch_async(dispatch_get_main_queue(), ^{
    @autoreleasepool {
      NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
      NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
      if (DEBUG_DISCOVER) NSLog(@"Heurika: %@", msg);
      if ([msg rangeOfString:@"GET /"].location != NSNotFound) {
        lastSocket = sock;
        NSLog(@"We have a http request");
        NSRange range = [msg rangeOfString:@"GET /"];
        NSString *newMsg = [msg substringFromIndex:range.location + range.length];
        newMsg = [newMsg substringToIndex:[newMsg rangeOfString:@"HTTP"].location];
        NSLog(@"Stripped: %@", newMsg);
        [[NSNotificationCenter defaultCenter] postNotificationName:TCPServerNewMsgReceived object:newMsg];
      } else if ([msg rangeOfString:@"Ambilight:"].location != NSNotFound) {
        NSRange range = [msg rangeOfString:@"Ambilight:"];
        msg = [msg substringFromIndex:range.location+range.length];
        [[NSNotificationCenter defaultCenter] postNotificationName:TCPServerNewMsgReceived object:msg];
      } else if (msg == nil) {
        if (DEBUG_TCP) NSLog(@"Error converting received data into UTF-8 String");
      }
    }
  });
  // Allow new data comming in
  [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

/**
 * This method is called if a read has timed out.
 * It allows us to optionally extend the timeout.
 * We use this method to issue a warning to the user prior to disconnecting them.
 **//*
     - (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
     elapsed:(NSTimeInterval)elapsed
     bytesDone:(NSUInteger)length {
     if (elapsed <= READ_TIMEOUT) {
     NSString *warningMsg = @"Are you still there?\r\n";
     NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
     
     [sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];
     
     return READ_TIMEOUT_EXTENSION;
     }
     
     return 0.0;
     }*/

/*
 * If a socket disconnected, remove it from the list of sockets
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
  // If the socket is not equal to the listening sockets
  if (sock != listenSocket) {
    dispatch_async(dispatch_get_main_queue(), ^{
      @autoreleasepool {
        if (DEBUG_TCP) NSLog(@"Client Disconnected");
      }
    });
    // Remove from the list of sockets
    @synchronized(connectedSockets) {
      [connectedSockets removeObject:sock];
    }
  }
}


@end
