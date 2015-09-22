//
//  PGPPacketHelper.m
//  CTOpenSSLWrapper
//
//  Created by Martin on 14.09.15.
//  Copyright (c) 2015 Home. All rights reserved.
//

#import "PGPPacketParser.h"

#import "PEMHelper.h"
#import "PGPPackets/PGPPublicKeyEncryptedSessionKeyPacket.h"
#import "PGPPackets/PGPPublicKeyPacket.h"
#import "PGPPackets/PGPSecretKeyPacket.h"
#import "PGPPackets/PGPSymmetricEncryptedIntegrityProtectedDataPacket.h"

#import <openssl/ossl_typ.h>
#import <openssl/bn.h>
#import <openssl/rsa.h>
#import <openssl/pem.h>
#import <openssl/err.h>

@implementation PGPPacketParser

+ (id)sharedManager {
    static PGPPacketParser *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id)init {
    if (self = [super init]) {
        id arrays[20];
        for (int i = 0; i < 20; i++) {
            arrays[i] =[[NSMutableArray alloc] init];
        }
        self.packets = [NSArray arrayWithObjects:arrays count:20];
    }
    return self;
}

- (void) addPacketWithTag:(int)tag andFormat:(int)format andData:(NSData *)data {
    PGPPacket *packet = NULL;
    switch (tag) {
        case 1:
            packet = [[PGPPublicKeyEncryptedSessionKeyPacket alloc] initWithBytes:data andWithTag:tag andWithFormat:format];
            if ([PGPPacketParser parsePublicKeyEncryptedSessionKeyPacket:packet] == -1) {
                // error
            }
            break;
        case 5: // SecretKeyPacket
        case 7: // SecretSubKeyPacket
            packet = [[PGPSecretKeyPacket alloc] initWithBytes:data andWithTag:tag andWithFormat:format];
            if ([PGPPacketParser parseSecretKeyPacket:packet] == -1) {
                // error
            }
            break;
        case 6:  // PublicKeyPacket
        case 14: // PublicSubKeyPacket
            packet = [[PGPPublicKeyPacket alloc] initWithBytes:data andWithTag:tag andWithFormat:format];
            if ([PGPPacketParser parsePublicKeyPacket:packet] == -1) {
                // error
            }
            break;
        case 18:
            packet = [[PGPSymmetricEncryptedIntegrityProtectedDataPacket alloc] initWithBytes:data andWithTag:tag andWithFormat:format];
            if ([PGPPacketParser parseSymmetricEncryptedIntegrityProtectedDataPacket:packet] == -1) {
                // error
            }
            break;
        default:
            return;
            break;
    }
    [[self.packets objectAtIndex:packet.tag] addObject:packet];
}

+ (int)extractPacketsFromBytes:(NSData*)bytes atPostion:(int)position {
    unsigned char* data = (unsigned char*)bytes.bytes;
    
    int pos = position;
    int packet_tag = -1;
    int packet_format = 0; //0 = old format; 1 = new format
    int packet_length_type = -1;
    size_t packet_length = -1;
    int packet_header = data[pos++];
    
    if ((packet_header & 0x80) == 0) {
        return -1;
    }
    
    //Check format
    if ((packet_header & 0x40) != 0){ //RFC 4.2. Bit 6 -- New packet format if set
        packet_format = 1;
    }
    
    //Get tag
    if (packet_format) {
        //new format
        packet_tag = packet_header & 0x3F; //RFC 4.2. Bits 5-0 -- packet tag
    }else {
        //old format
        packet_tag = (packet_header & 0x3C) >> 2; //RFC 4.2. Bits 5-2 -- packet tag
        packet_length_type = packet_header & 0x03; //RFC 4.2. Bits 1-0 -- length-type
    }
    
    //Get packet length
    if (!packet_format) {
        //RFC 4.2.1. Old Format Packet Lengths
        switch (packet_length_type) {
            case 0:
                //RFC: The packet has a one-octet length.  The header is 2 octets long.
                packet_length =  data[pos++];
                break;
            case 1:
                //RFC: The packet has a two-octet length.  The header is 3 octets long.
                packet_length = ( data[pos++] << 8);
                packet_length = packet_length |  data[pos++];
                break;
            case 2:
                //RFC: The packet has a four-octet length.  The header is 5 octets long.
                packet_length = ( data[pos++] << 24);
                packet_length = packet_length | ( data[pos++] << 16);
                packet_length = packet_length | ( data[pos++] << 8);
                packet_length = packet_length |  data[pos++];
                break;
            case 3:
                //TODO
                return -1;
                break;
            default:
                return -1;
                break;
        }
    }else {
        //RFC 4.2.2. New Format Packet Lengths
        int first_octet =  data[pos++];
        
        if(first_octet < 192) {
            //RFC 4.2.2.1. One-Octet Lengths
            packet_length = first_octet;
        } else if (first_octet < 234) {
            //RFC 4.2.2.2. Two-Octet Lengths
            packet_length = ((first_octet - 192) << 8) + ( data[pos++]) + 192;
        } else if (first_octet == 255) {
            //RFC 4.2.2.3. Five-Octet Lengths
            packet_length = ( data[pos++] << 24);
            packet_length = packet_length | ( data[pos++] << 16);
            packet_length = packet_length | ( data[pos++] << 8);
            packet_length = packet_length |  data[pos++];
        } else {
            //TODO
            /*RFC: When the length of the packet body is not known in advance by the issuer,
             Partial Body Length headers encode a packet of indeterminate length,
             effectively making it a stream.*/
            return -1;
        }
    }
    
    //Get Packet_bytes
    unsigned char* packet_bytes = data + pos;
    
    [[self sharedManager] addPacketWithTag:packet_tag andFormat:packet_format andData:[NSData dataWithBytes:(const void*)packet_bytes length:packet_length]];
    
    if (bytes.length <= pos+packet_length+1){
        return 0; //End of bytes
    }
    
    return pos+packet_length;
}

+ (int)parsePublicKeyPacket:(PGPPublicKeyPacket*) packet {
    int pos = 0;
    unsigned char* bytes = (unsigned char*)[packet.bytes bytes];
    int version =  bytes[pos++];
    NSLog(@"PGP public key version: %d", version);
    
    if (version == 3 || version == 4) {
        packet.creationTime = bytes[pos] << 24 | bytes[pos+1] << 16 | bytes[pos+2] << 8 | bytes[pos+3];
        pos += 4;
        
        if (version == 3) {
            packet.daysTillExpiration = bytes[pos] << 8 | bytes[pos+1];
            pos += 2;
        }
    } else {
        return -1;
    }
    
    packet.algorithm =  bytes[pos++];
    if (packet.algorithm != 1) {
        return -1;
    }
    
    unsigned char* bmpi = bytes + pos;
    int p = 0;
    int mpiCount = 2; // only rsa supported at the moment
    
    for (int i = 0; i < mpiCount && p < [packet.bytes length]-pos; i++) {
        double len = (bmpi[p] << 8) | bmpi[p+1];
        int byteLen = ceil(len / 8);
        unsigned char mpi[byteLen];
        for (int j = 0; j < byteLen; j++) {
            mpi[j] = bmpi[2+j+p];
        }
        [packet.mpis addObject:[NSData dataWithBytes:(const void*)mpi length:byteLen]];
        p += byteLen+2;
    }
    
    return p+pos; // bytes read
}

+ (int)parseSecretKeyPacket:(PGPSecretKeyPacket *)packet{
    int pos = 0;
    unsigned char* bmpi = NULL;
    int p = 0;
    int mpiCount = 0;
    unsigned char* bytes = (unsigned char*)[packet.bytes bytes];
    
    //Extract PublicKey from packet
    PGPPublicKeyPacket *pubKey = [[PGPPublicKeyPacket alloc] initWithBytes:packet.bytes andWithTag:packet.tag andWithFormat:packet.format];
    pos = [PGPPacketParser parsePublicKeyPacket:pubKey];
    if (pos == -1) {
        return -1;
    }
    packet.pubKey = pubKey;
    
    packet.s2k = bytes[pos++];
    
    switch (packet.s2k) {
        case 0:
            // Indicates that the secret-key data is not encrypted
            // Get MPIs
            bmpi = bytes + pos;
            mpiCount = 4; // only rsa supported at the moment
            
            for (int i = 0; i < mpiCount && p < ([packet.bytes length] - pos); i++) {
                double len = bmpi[p] << 8 | bmpi[p+1];
                int byteLen = ceil(len/8);
                
                unsigned char mpi[byteLen];
                for (int j = 0; j < byteLen; j++) {
                    mpi[j] = bmpi[2+j+p];
                }
                [packet.mpis addObject:[NSData dataWithBytes:(const void*)mpi length:byteLen]];
                p += byteLen+2;
            }
            break;
        case 255:
        case 254:
            // Indicates that a string-to-key specifier is being given
            break;
        default:
            // Any other value is a symmetric-key encryption algorithm identifier
            break;
    }
    
    return p+pos; // bytes read
}

+ (int)parsePublicKeyEncryptedSessionKeyPacket:(PGPPublicKeyEncryptedSessionKeyPacket *)packet {
    int pos = 0;
    unsigned char* bytes = (unsigned char*)[packet.bytes bytes];
    packet.version = bytes[pos++];
    packet.pubKeyID = (unsigned long long)bytes[pos] << 56 |
                      (unsigned long long)bytes[pos+1] << 48 |
                      (unsigned long long)bytes[pos+2] << 40 |
                      (unsigned long long)bytes[pos+3] << 32 |
                      (unsigned int)bytes[pos+4] << 24 |
                      (unsigned int)bytes[pos+5] << 16 |
                      (unsigned int)bytes[pos+6] << 8 |
                      (unsigned int)bytes[pos+7];
    pos += 8;
    packet.algorithm = bytes[pos++];
    
    // Get MPI
    unsigned char* bmpi = bytes + pos;
    
    double len = bmpi[0] << 8 | bmpi[1];
    int byteLen = ceil(len/8);
    
    unsigned char mpi[byteLen];
    for (int j = 0; j < byteLen; j++) {
        mpi[j] = bmpi[j+2];
    }
    [packet.mpis addObject:[NSData dataWithBytes:(const void*)mpi length:byteLen]];
    
    return pos+byteLen+2; // bytes read
}



+ (int)parseSymmetricEncryptedIntegrityProtectedDataPacket:(PGPSymmetricEncryptedIntegrityProtectedDataPacket *)packet{
    int pos = 0;
    unsigned char* bytes = (unsigned char*)[packet.bytes bytes];
    packet.version = bytes[pos++]; //RFC: A one-octet version number.  The only currently defined value is 1.
    
    if (packet.version != 1) {
        return -1;
    }
    
    //Encrypted data, the output of the selected symmetric-key cipher operating in Cipher Feedback mode with shift amount equal to the block size of the cipher (CFB-n where n is the block size)
    unsigned char data[[packet.bytes length] - pos];
    for (int i = 0; i < [packet.bytes length]-pos; i++) {
        data[i] = bytes[i+pos];
    }
    packet.encryptedData = [NSData dataWithBytes:data length:([packet.bytes length]-pos)];
    
    return [packet.bytes length];
}

@end
