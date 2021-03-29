//
//  Ambilight.h
//  LivingHome
//
//  Created by Benjamin Völker on 17.05.13.
//
//

#import <Foundation/Foundation.h>

@interface Screen : NSObject {
    CGDirectDisplayID displayId;
    CGSize resolution;
}

@property (assign) CGDirectDisplayID displayId;
@property (assign) CGSize resolution;

@end
