//
//  MIT License
//
//  Copyright (c) 2020 Daniel Lupiañez Casares
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import "StoreKitOverlayManager.h"
#import <StoreKit/StoreKit.h>

typedef void (*StoreKitOverlayManagerCallbackDelegate)(uint overlayId,  const char* payload);

@interface StoreKitOverlayManager () <SKOverlayDelegate>
@property (nonatomic, strong) NSMutableDictionary<NSValue *, NSNumber *> *overlaysInProgress;
@property (nonatomic, assign) StoreKitOverlayManagerCallbackDelegate mainCallback;
@property (nonatomic, weak) NSOperationQueue *callingOperationQueue;
@end

@implementation StoreKitOverlayManager

+ (instancetype) sharedManager
{
    static StoreKitOverlayManager *_defaultManager = nil;
    static dispatch_once_t defaultManagerInitialization;
    
    dispatch_once(&defaultManagerInitialization, ^{
        _defaultManager = [[StoreKitOverlayManager alloc] init];
    });
    
    return _defaultManager;
}

- (instancetype) init
{
    self = [super init];
    if (self)
    {
        _overlaysInProgress = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void) presentForOverlayId:(uint)overlayId andPayloadDictionary:(NSDictionary *)payloadDictionary
{
    NSString *appIdentifier = [self getStringForKey:@"_appIdentifier" fromPayloadDictionary:payloadDictionary defaultValue:nil];
    if (appIdentifier != nil)
    {
        [self presentForApplicationWithOverlayId:overlayId applicationIdentifier:appIdentifier andPayloadDictionary:payloadDictionary];
    }
    else
    {
        [self presentForAppClipWithOverlayId:overlayId andPayloadDictionary:payloadDictionary];
    }
}

- (void) dismissAll
{
    if (@available(iOS 14.0, *))
    {
        UIWindowScene *mainWindowScene = [self getMainActiveWindowScene];
        [SKOverlay dismissOverlayInScene:mainWindowScene];
    }
}

- (UIWindowScene *) getMainActiveWindowScene
API_AVAILABLE(ios(13.0))
{
    for (UIScene *scene in [[[UIApplication sharedApplication] connectedScenes] allObjects]) {
        if ([scene activationState] == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]])
        {
            return (UIWindowScene *)scene;
        }
    }
    
    return nil;
}

- (void) presentForApplicationWithOverlayId:(uint)overlayId
                      applicationIdentifier:(NSString *)applicationIdentifier
                       andPayloadDictionary:(NSDictionary *)payloadDictionary
{
    if (@available(iOS 14.0, *)) {
        SKOverlayPosition position = [self getIntegerForKey:@"_position" fromPayloadDictionary:payloadDictionary defaultValue:SKOverlayPositionBottom];
        BOOL isUserDismissible = [self getBooleanForKey:@"_userDismissible" fromPayloadDictionary:payloadDictionary defaultValue:YES];
        NSString *campaignToken = [self getStringForKey:@"_campaignToken" fromPayloadDictionary:payloadDictionary defaultValue:nil];
        NSString *providerToken = [self getStringForKey:@"_providerToken" fromPayloadDictionary:payloadDictionary defaultValue:nil];
        NSDictionary *additionalValues = [self getDictionaryForKey:@"_additionalValues" fromPayloadDictionary:payloadDictionary defaultValue:nil];
        
        SKOverlayAppConfiguration *appConfig = [[SKOverlayAppConfiguration alloc] initWithAppIdentifier:applicationIdentifier position:position];
        [appConfig setUserDismissible:isUserDismissible];
        [appConfig setCampaignToken:campaignToken];
        [appConfig setProviderToken:providerToken];
        
        for (id additionalKey in [additionalValues allKeys]) {
            // Ignore non-string keys
            if (![additionalKey isKindOfClass:[NSString class]])
            {
                continue;
            }
            
            [appConfig setAdditionalValue:[additionalValues objectForKey:additionalKey] forKey:additionalKey];
        }
        
        SKOverlay *overlay = [[SKOverlay alloc] initWithConfiguration:appConfig];
        [self presentOverlay:overlay forOverlayId:overlayId];
    } else {
        NSError *error = [self internalErrorWithCode:-32 andMessage:@"Unsupported iOS version. SKOverlay is only available from iOS 14.0"];
        [self sendError:error forOverlayWithId:overlayId];
    }
}

- (void) presentForAppClipWithOverlayId:(uint)overlayId
                   andPayloadDictionary:(NSDictionary *)payloadDictionary
{
    if (@available(iOS 14.0, *)) {
        SKOverlayPosition position = [self getIntegerForKey:@"_position" fromPayloadDictionary:payloadDictionary defaultValue:SKOverlayPositionBottom];
        NSString *campaignToken = [self getStringForKey:@"_campaignToken" fromPayloadDictionary:payloadDictionary defaultValue:nil];
        NSString *providerToken = [self getStringForKey:@"_providerToken" fromPayloadDictionary:payloadDictionary defaultValue:nil];
        NSDictionary *additionalValues = [self getDictionaryForKey:@"_additionalValues" fromPayloadDictionary:payloadDictionary defaultValue:nil];
        
        SKOverlayAppClipConfiguration *appClipConfig = [[SKOverlayAppClipConfiguration alloc] initWithPosition:position];
        [appClipConfig setCampaignToken:campaignToken];
        [appClipConfig setProviderToken:providerToken];
        
        for (id additionalKey in [additionalValues allKeys]) {
            // Ignore non-string keys
            if (![additionalKey isKindOfClass:[NSString class]])
            {
                continue;
            }
            
            [appClipConfig setAdditionalValue:[additionalValues objectForKey:additionalKey] forKey:additionalKey];
        }
        
        SKOverlay *overlay = [[SKOverlay alloc] initWithConfiguration:appClipConfig];
        [self presentOverlay:overlay forOverlayId:overlayId];
    } else {
        NSError *error = [self internalErrorWithCode:-32 andMessage:@"Unsupported iOS version. SKOverlay is only available from iOS 14.0"];
        [self sendError:error forOverlayWithId:overlayId];
    }
}

- (void) presentOverlay:(SKOverlay *)overlay forOverlayId:(uint)overlayId API_AVAILABLE(ios(14.0))
{
    UIWindowScene *mainWindowScene = [self getMainActiveWindowScene];
    NSValue *overlayAsKey = [NSValue valueWithNonretainedObject:overlay];
    [[self overlaysInProgress] setObject:@(overlayId) forKey:overlayAsKey];
    [overlay setDelegate:self];
    [overlay presentInScene:mainWindowScene];
}

#pragma mark - Deserializing

- (NSInteger) getIntegerForKey:(NSString *)key fromPayloadDictionary:(NSDictionary *)payloadDictionary defaultValue:(NSInteger)defaultValue
{
    id integerNumber = [payloadDictionary objectForKey:key];
    if (integerNumber != nil && [integerNumber isKindOfClass:[NSNumber class]])
    {
        return [integerNumber integerValue];
    }
    
    return defaultValue;
}

- (BOOL) getBooleanForKey:(NSString *)key fromPayloadDictionary:(NSDictionary *)payloadDictionary defaultValue:(BOOL)defaultValue
{
    id boolNumber = [payloadDictionary objectForKey:key];
    if (boolNumber != nil && [boolNumber isKindOfClass:[NSNumber class]])
    {
        return [boolNumber boolValue];
    }
    
    return defaultValue;
}

- (NSString *) getStringForKey:(NSString *)key fromPayloadDictionary:(NSDictionary *)payloadDictionary defaultValue:(NSString *)defaultValue
{
    id stringValue = [payloadDictionary objectForKey:key];
    if (stringValue != nil && [stringValue isKindOfClass:[NSString class]])
    {
        return (NSString*) stringValue;
    }
    
    return defaultValue;
}

- (NSDictionary *) getDictionaryForKey:(NSString *)key fromPayloadDictionary:(NSDictionary *)payloadDictionary defaultValue:(NSDictionary *)defaultValue
{
    id dictionaryValue = [payloadDictionary objectForKey:key];
    if (dictionaryValue != nil && [dictionaryValue isKindOfClass:[NSDictionary class]])
    {
        return (NSDictionary*) dictionaryValue;
    }
    
    return defaultValue;
}

- (NSError *)internalErrorWithCode:(NSInteger)code andMessage:(NSString *)message
{
    return [NSError errorWithDomain:@"com.lupidan.SKOverlayManager"
                                   code:code
                               userInfo:@{NSLocalizedDescriptionKey : message}];
}

#pragma mark - Sending payloads

- (void) sendError:(NSError *)error forOverlayWithId:(uint)overlayId
{
    NSDictionary *nativePayload = @{
        @"_messageType" : @"error",
        @"_hasError" : @YES,
        @"_hasTransitionContext" : @NO,
        @"_error" : [self dictionaryForNSError:error],
    };
    
    [self sendNativePayload:nativePayload forOverlayId:overlayId];
}

- (void) sendTransitionContext:(SKOverlayTransitionContext *)transitionContext forOverlayWithId:(uint)overlayId andMessageType:(NSString *)messageType
API_AVAILABLE(ios(14.0))
{
    NSDictionary *nativePayload = @{
        @"_messageType" : messageType,
        @"_hasError" : @NO,
        @"_hasTransitionContext" : @YES,
        @"_transitionContext" : [self dictionaryForTransitionContext:transitionContext],
    };
    
    [self sendNativePayload:nativePayload forOverlayId:overlayId];
}

- (void) sendNativePayload:(NSDictionary *)payloadDictionary forOverlayId:(uint)overlayId
{
//    if ([self mainCallback] == NULL)
//        return;
    
    NSError *error = nil;
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payloadDictionary options:0 error:&error];
    NSString *payloadString;
    if (error)
    {
        payloadString = [NSString stringWithFormat:@"Serialization error %@", [error localizedDescription]];
    }
    else
    {
        payloadString =  [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding];
    }
    
    NSLog(@"%@", payloadString);
    if ([self mainCallback] == NULL)
        return;
    
    if ([self callingOperationQueue])
    {
        [[self callingOperationQueue] addOperationWithBlock:^{
            [self mainCallback](overlayId, [payloadString UTF8String]);
        }];
    }
    else
    {
        [self mainCallback](overlayId, [payloadString UTF8String]);
    }
}

#pragma mark - Serializing

- (NSDictionary *) dictionaryForNSError:(NSError *)error
{
    if (!error)
        return nil;
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [result setValue:@([error code]) forKey:@"_code"];
    [result setValue:[error domain] forKey:@"_domain"];
    [result setValue:[error localizedDescription] forKey:@"_localizedDescription"];
    [result setValue:[error localizedRecoveryOptions] forKey:@"_localizedRecoveryOptions"];
    [result setValue:[error localizedRecoverySuggestion] forKey:@"_localizedRecoverySuggestion"];
    [result setValue:[error localizedFailureReason] forKey:@"_localizedFailureReason"];
    return [result copy];
}

- (NSDictionary *) dictionaryForTransitionContext:(SKOverlayTransitionContext *)transitionContext
API_AVAILABLE(ios(14.0))
{
    if (!transitionContext)
        return nil;
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [result setValue:[self dictionaryForRect:[transitionContext startFrame]] forKey:@"_startFrame"];
    [result setValue:[self dictionaryForRect:[transitionContext endFrame]] forKey:@"_endFrame"];
    return [result copy];
}

- (NSDictionary *) dictionaryForRect:(CGRect)rect
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [result setValue:@(rect.origin.x) forKey:@"_x"];
    [result setValue:@(rect.origin.y) forKey:@"_y"];
    [result setValue:@(rect.size.width) forKey:@"_width"];
    [result setValue:@(rect.size.height) forKey:@"_height"];
    return [result copy];
}

#pragma mark - SKOverlayDelegate protocol implementation

- (void) storeOverlay:(SKOverlay *)overlay didFailToLoadWithError:(NSError *)error
API_AVAILABLE(ios(14.0))
{
    NSValue *overlayAsKey = [NSValue valueWithNonretainedObject:overlay];
    NSNumber *overlayIdNumber = [[self overlaysInProgress] objectForKey:overlayAsKey];
    if (overlayIdNumber)
    {
        [[self overlaysInProgress] removeObjectForKey:overlayAsKey];
        [self sendError:error forOverlayWithId:[overlayIdNumber unsignedIntValue]];
    }
}

- (void) storeOverlay:(SKOverlay *)overlay willStartPresentation:(SKOverlayTransitionContext *)transitionContext
API_AVAILABLE(ios(14.0))
{
    NSValue *overlayAsKey = [NSValue valueWithNonretainedObject:overlay];
    NSNumber *overlayIdNumber = [[self overlaysInProgress] objectForKey:overlayAsKey];
    if (overlayIdNumber)
    {
        [self sendTransitionContext:transitionContext
                   forOverlayWithId:[overlayIdNumber unsignedIntValue]
                     andMessageType:@"willStartPresentation"];
    }
}

- (void) storeOverlay:(SKOverlay *)overlay didFinishPresentation:(SKOverlayTransitionContext *)transitionContext
API_AVAILABLE(ios(14.0))
{
    NSValue *overlayAsKey = [NSValue valueWithNonretainedObject:overlay];
    NSNumber *overlayIdNumber = [[self overlaysInProgress] objectForKey:overlayAsKey];
    if (overlayIdNumber)
    {
        [self sendTransitionContext:transitionContext
                   forOverlayWithId:[overlayIdNumber unsignedIntValue]
                     andMessageType:@"didFinishPresentation"];
    }
}

- (void) storeOverlay:(SKOverlay *)overlay willStartDismissal:(SKOverlayTransitionContext *)transitionContext
API_AVAILABLE(ios(14.0))
{
    NSValue *overlayAsKey = [NSValue valueWithNonretainedObject:overlay];
    NSNumber *overlayIdNumber = [[self overlaysInProgress] objectForKey:overlayAsKey];
    if (overlayIdNumber)
    {
        [self sendTransitionContext:transitionContext
                   forOverlayWithId:[overlayIdNumber unsignedIntValue]
                     andMessageType:@"willStartDismissal"];
    }
}

- (void) storeOverlay:(SKOverlay *)overlay didFinishDismissal:(SKOverlayTransitionContext *)transitionContext
API_AVAILABLE(ios(14.0))
{
    NSValue *overlayAsKey = [NSValue valueWithNonretainedObject:overlay];
    NSNumber *overlayIdNumber = [[self overlaysInProgress] objectForKey:overlayAsKey];
    if (overlayIdNumber)
    {
        [[self overlaysInProgress] removeObjectForKey:overlayAsKey];
        [self sendTransitionContext:transitionContext
                   forOverlayWithId:[overlayIdNumber unsignedIntValue]
                     andMessageType:@"didFinishDismissal"];
    }
}

@end

#pragma mark - C wrapper calls

void StoreKitOverlayManager_SetupCallbackDelegate(StoreKitOverlayManagerCallbackDelegate callbackDelegate)
{
    [[StoreKitOverlayManager sharedManager] setMainCallback:callbackDelegate];
    [[StoreKitOverlayManager sharedManager] setCallingOperationQueue: [NSOperationQueue currentQueue]];
}

void StoreKitOverlayManager_Present(uint overlayId, const char* _Nullable payloadCString)
{
    NSError *error = nil;
    NSData *payloadData = [NSData dataWithBytes:payloadCString length:strlen(payloadCString)];
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:&error];
    if (error)
    {
        [[StoreKitOverlayManager sharedManager] sendError:error forOverlayWithId:overlayId];
    }
    else
    {
        [[StoreKitOverlayManager sharedManager] presentForOverlayId:overlayId andPayloadDictionary:payload];
    }
}

void StoreKitOverlayManager_DismissAll()
{
    [[StoreKitOverlayManager sharedManager] dismissAll];
}
