//
//  FYActor.h
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

#import <Foundation/Foundation.h>


@class FYClient, FYMessage;


/**
 Used to dynamically bind to meta channel messages.
 */
@protocol FYActor

/**
 The given message was received by the given client.
 
 @param client   The client who received the message.
 
 @param message  The message which was received.
 */
- (void)client:(FYClient *)client receivedMessage:(FYMessage *)message;

@end


/**
 Handle received message by a selector which is performed on a given target.
 */
@interface FYSelTargetActor : NSObject<FYActor>

/**
 The target on which the selector will be performed.
 */
@property (nonatomic, weak) id<NSObject> target;

/**
 The selector which will be performed on target.
 Needs two arguments: as first argument an instance of [FYClient] and as second argument and instance of [FYMessage]
 will be given.
 */
@property (nonatomic, assign) SEL selector;

/**
 Initializer
 
 @param target    The value for the property target
 
 @param selector  The value for the property selector
 */
- (id)initWithTarget:(id<NSObject>)target selector:(SEL)selector;

@end



/**
 Used by [FYBlockActor] to respond to [FYActor]'s protocol's message.
 */
typedef void(^FYActorBlock)(FYClient *, FYMessage *);


/**
 Handle received message by a block
 */
@interface FYBlockActor : NSObject<FYActor>

/**
 The actor, which will be executed when a message is received
 */
@property (nonatomic, copy) FYActorBlock block;

/**
 Chain an actor once with a block an after the block was executed one single time, remove the chain from its place by
 executing a restore block where the original actor will be given as argument.
 
 Return value must replace parameter `actor` to take effect.
 
     self.connectActor = [FYBlockActor chain:self.connectActor
                                        once:^(FYClient *client, FYMessage *message){
                                            NSLog(@"This is done once.");
                                        } restore:^(id<FYActor> actor){
                                            self.connectActor = actor;
                                        }]
 
 @param actor          Actor to be chained once. This will be executed before actorBlock and given as first argument to
 restoreBlock.
 
 @param actorBlock     Block to execute once.
 
 @param restoreBlock   Restore action to replace return value back by actor.
 */
+ (instancetype)chain:(id<FYActor>)actor once:(FYActorBlock)actorBlock restore:(void(^)(id<FYActor>))restoreBlock;

/**
 Initializer
 
 @param block  The actor, which will be executed when a message is received.
 */
- (id)initWithBlock:(FYActorBlock)block;

@end
