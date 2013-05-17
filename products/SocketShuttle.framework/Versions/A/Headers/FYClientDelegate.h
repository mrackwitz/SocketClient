//
//  FYClientDelegate.h
//  SocketShuttle
//
//  Created by Marius Rackwitz on 08.05.13.
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
 The `FYClientDelegate` protocol is used to receive state information and intercept methods.
 All defined messages are optional to implement.
 
 In the internal used `FYDelegateProxy` the messages are invocated on the real delegate using
 <NSInvocation>. So it will in case of extension not possible to grasp the return value of
 non-void messages. Therefore `inout`-pointers are used.
 */
@protocol FYClientDelegate<NSObject>

@optional

/**
 The client was successfully connected.
 
 This is sent after web socket open, Bayeux handshake and Bayeux connect were successfully executed.
 The client is now read for channel subscriptions or event publications.
 
 @param client    The client whose connection was established.
 */
- (void)clientConnected:(FYClient *)client;

/**
 The subscription to a channel succeed.
 
 This is sent when the subscription to a channel was confirmed and the client will receive events on this channel with
 the registrated callback.
 
 @param client    The client whose channel subscription succeed.
 
 @param channel   The channel to which the subscription succeed.
 */
- (void)client:(FYClient *)client subscriptionSucceedToChannel:(NSString *)channel;

/**
 The client received an unexpected message.
 
 This is called when the client received a message on a channel, which is not matched to a registrated callback.
 This could be handled in a custom manner and does not lead to a fail.
 
 @param client    The client which received an unexpected message.

 @param message   The channel to which the subscription succeed.
 */
- (void)client:(FYClient *)client receivedUnexpectedMessage:(FYMessage *)message;

/**
 The client was disconnected.
 
 Some event led to an disconnect, either successfull because wished, or because the connection failed, than an error
 message is given.
 If error is given and a message is given, then the connection failed in Bayeux or BayeuxAdvice level.
 If error is given and no message is given, then the underlying web socket connection failed.
 
 @param client    The client which was disconnected.
 
 @param message   The message which led to the connection fail.
 
 @param error     An error object describing what was going wrong.
 */
- (void)clientDisconnected:(FYClient *)client withMessage:(FYMessage *)message error:(NSError *)error;

/**
 The client had an internal error, which could effect the connection state and should be handled.
 
 There was an internal error in communication, which was neither caused by an internal inconsistency (, which should
 have led to a crash) nor by a connection problem. The delegate has to decide on its own how to react.
 
 @param client    The client which failed.
 
 @param error     An error object describing what was going wrong.
 */
- (void)client:(FYClient *)client failedWithError:(NSError *)error;

/**
 The client was advised to retry by doing a connect.
 
 The client MAY attempt to reconnect with a /meta/connect after the interval (as defined by "interval" advice or
 client-default backoff), and with the same credentials.
 Can be used to implement a backoff strategy to increase the interval if requests to the server fail without new advice
 being received from the server.
 
 @param client    The client which was advised to retry.
 
 @param interval  Is by default given either as defined by server's "interval" advice or by client-default backoff.
 Values lower then zero will cause that no reconnect is tried.
 */
- (void)clientWasAdvisedToRetry:(FYClient *)client retryInterval:(inout NSTimeInterval *)interval;

/**
 The client was advised to retry by doing a handshake.
 
 The server has terminated any prior connection status and the client MUST reconnect with a /meta/handshake message.
 A client MUST NOT automatically retry if handshake reconnect has been received.
 
 @param client    The client which was advised to retry.
 
 @param retry     Is by default given as NO.
 */
- (void)clientWasAdvisedToHandshake:(FYClient *)client shouldRetry:(inout BOOL *)retry;

@end
