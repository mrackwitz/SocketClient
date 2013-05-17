//
//  AppDelegate.m
//  SocketShuttle
//
//  Created by Marius Rackwitz on 07.05.13.
//  Copyright (c) 2013 Marius Rackwitz. All rights reserved.
//

#import <SocketShuttle/SocketShuttle.h>
#import "AppDelegate.h"


/*
 Pretty symbolized callstack for uncaught exceptions
 author: Zane Claes
 link:   http://stackoverflow.com/a/7896769
 */
void uncaughtExceptionHandler(NSException* exception) {
    NSLog(@"CRASH: %@", exception);
    NSLog(@"Stack Trace: %@", exception.callStackSymbols);
}


@interface AppDelegate () <FYClientDelegate>

@property (nonatomic, retain) FYClient* client;

@end


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Init uncaught exception handler to pretty print stack traces
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    
    FYClient* client = [[FYClient alloc] initWithURL:[NSURL URLWithString:@"http://localhost:8000/faye"]];
    client.delegate = self;
    [client connectOnSuccess:^(FYClient *client) {
        [client subscribeChannel:@"/count" callback:^(NSDictionary *userInfo){
            NSLog(@"Current number: %d", [userInfo[@"number"] intValue]);
            
            /*// Increment
            [self performSelector:@selector(publishCount:)
                       withObject:@([userInfo[@"number"] intValue] + 1)
                       afterDelay:1];*/
         }];
        
        // Begin counting
        [client publish:@{
                @"sender": UIDevice.currentDevice.model,
                @"number": @1
            } onChannel:@"/count"];
     }];
    
    self.client = client;
    
    return YES;
}

- (void)publishCount:(NSNumber *)number {
    [self.client publish:@{
        @"sender": UIDevice.currentDevice.model,
        @"number": number
     } onChannel:@"/count"];
}

- (void)clientConnected:(FYClient *)client {
    NSLog(@"Connected");
}

- (void)client:(FYClient *)client subscriptionSucceedToChannel:(NSString *)channel {
    NSLog(@"Subscription succeed to channel: %@", channel);
}

- (void)client:(FYClient *)client receivedUnexpectedMessage:(FYMessage *)message {
    NSLog(@"Received unexpected message: %@", message);
}

- (void)client:(FYClient *)client disconnectedWithMessage:(FYMessage *)message error:(NSError *)error {
    NSLog(@"Disconnect: %@ - %@", message, error);
    if (error.code == FYErrorSocketClosed) {
        [client reconnect];
    } else if (!error && !message) {
        [client reconnect];
    } else {
        [client reconnect];
    }
}

- (void)client:(FYClient *)client failedWithError:(NSError *)error {
    NSLog(@"Error: %@", error);
}

- (void)clientWasAdvisedToRetry:(FYClient *)client retryInterval:(inout NSTimeInterval *)interval {
    NSLog(@"Retry: %.2f", interval ? *interval : 0);
}

- (void)clientWasAdvisedToHandshake:(FYClient *)client shouldRetry:(inout BOOL *)retry {
    NSLog(@"Handshake: %@", retry ? @YES : @NO);
}

@end
