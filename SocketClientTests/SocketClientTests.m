//
//  SocketClientTests.m
//  SocketClientTests
//
//  Created by Marius Rackwitz on 13.05.13.
//  Copyright (c) 2013 Marius Rackwitz. All rights reserved.
//
//
//  The MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "SocketClientTests.h"
#import "FYClient.h"



@interface FYClient ()

- (NSString *)generateMessageId;

@end



@interface SocketClientTests ()

@property (nonatomic, retain) FYClient *client;

@end


@implementation SocketClientTests

- (void)setUp {
    [super setUp];
    
    self.client = [[FYClient alloc] initWithURL:[NSURL URLWithString:@"http://localhost"]];
}

- (void)tearDown {
    [super tearDown];
    
    [self.client disconnect];
}

- (void)testEnforceDesignatedInitializer {
    STAssertThrows(^{
        FYClient *client = [[FYClient alloc] init];
        [client connect];
     }(), @"Not using the designated initializer should fail.");
}

- (void)testGenerateMessageIdAreNotEqual {
    NSString *messageId1 = [self.client generateMessageId];
    NSString *messageId2 = [self.client generateMessageId];
    STAssertFalse([messageId1 isEqualToString:messageId2],
                  @"Two generated message ids by %@ may not be equal.", NSStringFromSelector(@selector(generateMessageId)));
}

- (void)testPersistDoesNotAllowRelease {
    // Store weak ref and release our own reference.
    __weak FYClient *weakClient = self.client;
    [self.client persist];
    self.client = nil;
    
    STAssertNotNil(weakClient, @"Weak-ref must be hold.");
    
    // Release persistent reference by explicit disconnect. We don't need to be connected.
    [self.client disconnect];
    
    // Wait a moment to let ARC collect the weak garbage reference.
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        STAssertNil(weakClient, @"Weak-ref must be nil.");
     });
}

@end
