//
//  MATTestParams.m
//  MobileAppTracker
//
//  Created by John Bender on 12/19/13.
//  Copyright (c) 2013 HasOffers. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MATTestParams.h"
#import "MATTests.h"
#import "../MobileAppTracker/MobileAppTracker.h"
#import "../MobileAppTracker/Common/MATUtils.h"
#import "../MobileAppTracker/Common/MATKeyStrings.h"
#import "../MobileAppTracker/Common/MATEncrypter.h"

static NSString* const kDataItemKey = @"testBodyDataItems";
static NSString* const kReceiptItemKey = @"testBodyReceipt";
static NSString* const kAppleReceiptItemKey = @"testAppleReceipt";

@interface MATTestParams ()

@property (nonatomic, strong) NSMutableDictionary *params;

@end


@implementation MATTestParams

- (NSString*)description
{
    return [_params description];
}


- (id)copy
{
    id new = [[self class] new];
    ((MATTestParams*)new).params = [self.params mutableCopy];
    return new;
}


- (BOOL)isEqualToParams:(MATTestParams*)other
{
    if( _params == nil ) return FALSE;
    
    for( NSString *key in _params ) {
        if( ![other valueForKey:key] )
            return FALSE;
        if( ![[self valueForKey:key] isEqual:[other valueForKey:key]] )
            return FALSE;
    }
    
    return TRUE;
}


- (BOOL)isEmpty
{
    return (_params == nil);
}


#pragma mark - Data extractors

- (BOOL)extractParamsString:(NSString*)string
{
    //NSLog( @"params from string %@", string );
    NSArray *components = [string componentsSeparatedByString:@"&"];
    for( NSString *component in components ) {
        if( [component isEqualToString:@""] ) continue;
        
        NSArray *keyValue = [component componentsSeparatedByString:@"="];
        if( [keyValue count] != 2 ) continue;
        if( [keyValue[0] isEqualToString:@""] ) continue;
        
        if( [keyValue[0] isEqualToString:@"data"] ) {
            NSData *decodedData = [self decodeHexData:[keyValue[1] dataUsingEncoding:NSUTF8StringEncoding]];
            NSData *decryptedData = [self decodeHexData:[self aesDecrypt:kTestConversionKey data:decodedData]];
            NSString *decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
            return [self extractParamsString:[decryptedString stringByRemovingPercentEncoding]];
        }
        
        NSString *unencodedValue = keyValue[1];
        if( ![unencodedValue isEqualToString:@""] )
            unencodedValue = [unencodedValue stringByRemovingPercentEncoding];

        if( _params == nil )
            _params = [NSMutableDictionary dictionary];
        _params[keyValue[0]] = unencodedValue;
    }
    
    return TRUE;
}

- (BOOL)extractParamsJSON:(NSString*)json
{
    //NSLog( @"params from JSON %@", json );
    NSError *error = nil;
    NSDictionary *data = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    
    if( error )
        return FALSE;
    else {
        if( [data isKindOfClass:[NSDictionary class]] ) {
            if( data[MAT_KEY_DATA] != nil ) {
                NSArray *items = data[MAT_KEY_DATA];
                if( [items isKindOfClass:[NSArray class]] ) {
                    if( _params == nil )
                        _params = [NSMutableDictionary dictionary];
                    if( _params[kDataItemKey] == nil )
                        _params[kDataItemKey] = [NSMutableArray array];
                    for( NSDictionary *item in items ) {
                        if( [item isKindOfClass:[NSDictionary class]] )
                            [_params[kDataItemKey] addObject:item];
                        else
                            return FALSE;
                    }
                }
                else
                    return FALSE;
            }
            if( data[MAT_KEY_STORE_RECEIPT] != nil ) {
                if( _params == nil )
                    _params = [NSMutableDictionary dictionary];
                _params[kReceiptItemKey] = data[MAT_KEY_STORE_RECEIPT];
            }
            if( data[MAT_KEY_INSTALL_RECEIPT] != nil ) {
                if( _params == nil )
                    _params = [NSMutableDictionary dictionary];
                _params[kAppleReceiptItemKey] = data[MAT_KEY_INSTALL_RECEIPT];
            }
        }
        else
            return FALSE;
    }
    
    return TRUE;
}


- (NSString*)valueForKey:(NSString*)key
{
    return _params[key];
}


#pragma mark - Decryption

- (NSData *)decodeHexData:(NSData *)input {
    
    NSMutableData *resultData = [NSMutableData dataWithLength:([input length]) / 2];
    
    const unsigned char *hexBytes = [input bytes];
    unsigned char *resultBytes = [resultData mutableBytes];
    
    for(NSUInteger i = 0; i < [input length] / 2; i++) {
        resultBytes[i] = (char2hex(hexBytes[i + i]) << 4) | char2hex(hexBytes[i + i + 1]);
    }
    
    return resultData;
}

- (NSData *)aesDecrypt:(NSString *)mykey data:(NSData *)str
{
    long keyLength = [mykey length];
    if(keyLength != kCCKeySizeAES128 && keyLength != kCCKeySizeAES192 && keyLength != kCCKeySizeAES256)
    {
        return nil;
    }
    
    char keyBytes[keyLength + 1];
    bzero(keyBytes, sizeof(keyBytes));
    [mykey getCString:keyBytes maxLength:sizeof(keyBytes) encoding:NSUTF8StringEncoding];
    
    size_t numBytesEncrypted = 0;
    size_t encryptedLength = [str length] + kCCBlockSizeAES128;
    char encryptedBytes[encryptedLength +1];
    
    CCCryptorStatus result = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128 ,
                                     kCCOptionECBMode | kCCOptionPKCS7Padding,
                                     keyBytes,
                                     keyLength,
                                     NULL,
                                     [str bytes],
                                     [str length],
                                     encryptedBytes,
                                     encryptedLength,
                                     &numBytesEncrypted);
    
    
    if(result == kCCSuccess)
        return [NSData dataWithBytes:encryptedBytes length:numBytesEncrypted];
    
    return nil;
}


#pragma mark - Value assertions

- (BOOL)checkIsEmpty
{
    return (_params == nil);
}


- (BOOL)checkKeyHasValue:(NSString*)key
{
    return (_params[key] != nil);
}

- (BOOL)checkKey:(NSString*)key isEqualToValue:(NSString*)value
{
    return [self checkKeyHasValue:key] && [_params[key] isEqualToString:value];
}

- (BOOL)checkAppValues
{
    BOOL retval =
    [self checkKey:@"advertiser_id" isEqualToValue:kTestAdvertiserId] &&
    [self checkKey:@"package_name" isEqualToValue:kTestBundleId] &&
    [self checkKeyHasValue:@"ios_ifv"];
    
    if( !retval )
        NSLog( @"app values failed: %d %d %d", [self checkKey:@"advertiser_id" isEqualToValue:kTestAdvertiserId], [self checkKey:@"package_name" isEqualToValue:kTestBundleId], [self checkKeyHasValue:@"ios_ifv"] );
    
    return retval;
}

- (BOOL)checkSdkValues
{
    BOOL retval =
    [self checkKey:@"sdk" isEqualToValue:@"ios"] &&
    [self checkKeyHasValue:@"ver"] &&
    [self checkKeyHasValue:@"transaction_id"];
    
    if( !retval )
        NSLog( @"sdk values failed: %d %d %d", [self checkKey:@"sdk" isEqualToValue:@"ios"], [self checkKeyHasValue:@"ver"], [self checkKeyHasValue:@"transaction_id"] );
    
    return retval;
}

- (BOOL)checkDeviceValues
{
    BOOL retval =
    [self checkKeyHasValue:@"conversion_user_agent"] &&
    [self checkKeyHasValue:@"country_code"] &&
    [self checkKeyHasValue:@"language"] &&
    [self checkKeyHasValue:@"system_date"] &&
    [self checkKeyHasValue:@"device_brand"] &&
    [self checkKeyHasValue:@"device_cpu_type"] &&
    [self checkKeyHasValue:@"device_cpu_subtype"] &&
    [self checkKeyHasValue:@"device_model"] &&
    [self checkKeyHasValue:@"os_version"] &&
    [self checkKeyHasValue:@"insdate"] &&
    [self checkKey:@"os_jailbroke" isEqualToValue:@"0"];
    CGSize size = [[UIScreen mainScreen] bounds].size;
    [self checkKey:@"screen_size" isEqualToValue:[NSString stringWithFormat:@"%.fx%.f", size.width, size.height]];
    [self checkKey:@"screen_density" isEqualToValue:[@([[UIScreen mainScreen] scale]) stringValue]];
    
    if( !retval )
        NSLog( @"device values failed: %d %d %d %d %d %d %d %d %d %d %d", [self checkKeyHasValue:@"conversion_user_agent"], [self checkKeyHasValue:@"country_code"], [self checkKeyHasValue:@"language"], [self checkKeyHasValue:@"system_date"], [self checkKeyHasValue:@"device_brand"], [self checkKeyHasValue:@"device_cpu_type"], [self checkKeyHasValue:@"device_cpu_subtype"], [self checkKeyHasValue:@"device_model"], [self checkKeyHasValue:@"os_version"], [self checkKeyHasValue:@"insdate"], [self checkKey:@"os_jailbroke" isEqualToValue:@"0"] );
    
    NSString *sysDateString = [self valueForKey:@"system_date"];
    if( sysDateString ) {
        NSTimeInterval sysDate = [sysDateString longLongValue];
        NSTimeInterval now = round( [[NSDate date] timeIntervalSince1970] );
        NSTimeInterval elapsed = now - sysDate;
        if( elapsed < 0. || elapsed > 60. ) {
            NSLog( @"%lf elapsed since call's system date %lf (now %lf)", elapsed, sysDate, now );
            retval = NO;
        }
    }

    return retval;
}

- (BOOL)checkDefaultValues
{
    return
    [self checkAppValues] &&
    [self checkSdkValues] &&
    [self checkDeviceValues];
}

- (BOOL)checkDataItems:(NSArray*)items
{
    NSArray *foundItems = _params[kDataItemKey];
    if( [items count] != [foundItems count] )
        return FALSE;
    
    for( NSInteger i = 0; i < [foundItems count]; i++ ) {
        NSDictionary *foundItem = foundItems[i];
        MATEventItem *item = items[i];
        if( ![foundItem[@"item"] isEqualToString:item.item] ) {
            NSLog( @"names must be identical: sent '%@' and got '%@'", item.item, foundItem[@"item"] );
            return FALSE;
        }
        NSString *testString = [NSString stringWithFormat:@"%d", item.quantity];
        if( ![foundItem[@"quantity"] isEqualToString:testString] ) {
            NSLog( @"quantities must match: sent %d got %@", item.quantity, foundItem[@"quantity"] );
            return FALSE;
        }
        testString = [NSString stringWithFormat:@"%f", item.unitPrice];
        if( ![foundItem[@"unit_price"] isEqualToString:testString] ) {
            NSLog( @"prices must match: sent %f got %@", item.unitPrice, foundItem[@"unit_price"] );
            return FALSE;
        }
        testString = [NSString stringWithFormat:@"%f", item.revenue];
        if( ![foundItem[@"revenue"] isEqualToString:testString] ) {
            NSLog( @"revenues must match: sent %f got %@", item.revenue, foundItem[@"revenue"] );
            return FALSE;
        }
    }
    
    return TRUE;
}

- (BOOL)checkNoDataItems
{
    return (_params[kDataItemKey] == nil);
}

- (BOOL)checkReceiptEquals:(NSData*)receiptValue
{
    return [_params[kReceiptItemKey] isEqualToString:[MATUtils MATbase64EncodedStringFromData:receiptValue]];
}

- (BOOL)checkAppleReceiptEquals:(NSData*)receiptValue
{
    return [_params[kAppleReceiptItemKey] isEqualToString:[MATUtils MATbase64EncodedStringFromData:receiptValue]];
}

@end
