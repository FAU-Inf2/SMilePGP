//
//  SecretKeyPacket.m
//  CTOpenSSLWrapper
//
//  Created by Moritz Müller on 22.09.15.
//  Copyright (c) 2015 Home. All rights reserved.
//

#import "PGPPublicKeyPacket.h"

@implementation PGPPublicKeyPacket

- (id)initWithBytes:(NSData*)bytes andWithTag:(int)tag andWithFormat:(int)format {
    self = [super initWithBytes:bytes andWithTag:tag andWithFormat:format];
    if (self != nil) {
        self.mpis = [[NSMutableArray alloc] init];
    }
    return self;
}

@end
