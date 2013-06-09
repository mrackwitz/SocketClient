//
//  FYActor.m
//  SocketClient
//
//  Created by Marius Rackwitz on 09.05.13.
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

#import "FYActor.h"
#import "FYMessage.h"


@implementation FYSelTargetActor

- (id)initWithTarget:(id<NSObject>)target selector:(SEL)selector {
    self = [super init];
    if (self) {
        self.target = target;
        self.selector = selector;
    }
    return self;
}

- (void)client:(FYClient *)client receivedMessage:(FYMessage *)message {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.selector withObject:client withObject:message];
    #pragma clang diagnostic pop
}

@end



@implementation FYBlockActor

- (id)initWithBlock:(FYActorBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)chain:(id<FYActor>)actor once:(FYActorBlock)actorBlock restore:(void(^)(id<FYActor>))restoreBlock {
    return [[self alloc] initWithBlock:^(FYClient *client, FYMessage *message) {
        [actor client:client receivedMessage:message];
        
        actorBlock(client, message);
        restoreBlock(actor);
     }];
}

- (void)client:(FYClient *)client receivedMessage:(FYMessage *)message {
    self.block(client, message);
}

@end
