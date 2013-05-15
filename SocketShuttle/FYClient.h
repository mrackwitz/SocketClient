//
//  FYClient.h
//  SocketShuttle
//
//  Created by Marius Rackwitz on 07.05.13.
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
/** @refs
//  [45] http://svn.cometd.com/trunk/bayeux/bayeux.html#toc_45
*/

#import <Foundation/Foundation.h>
#import "FYClientDelegate.h"
#import "FYError.h"
#import "FYMessage.h"
#import "SRWebSocket.h"


/**
 Bayeux protocol meta channels
 */
const struct FYMetaChannels {
    __unsafe_unretained NSString *Handshake;
    __unsafe_unretained NSString *Connect;
    __unsafe_unretained NSString *Disconnect;
    __unsafe_unretained NSString *Subscribe;
    __unsafe_unretained NSString *Unsubscribe;
} FYMetaChannels;

/**
 Relevant Bayeux connection types
 */
const struct FYConnectionTypes {
    __unsafe_unretained NSString *LongPolling;      // Fallback - should be implemented, is actually not
    __unsafe_unretained NSString *CallbackPolling;  // Not implemented
    __unsafe_unretained NSString *WebSocket;        // Implemented
} FYConnectionTypes;

extern NSArray *FYSupportedConnectionTypes();

/**
 Default reconnect interval on `message.attempt.reconnect = retry` if no "interval" attempt was given by the server.
 */
extern const NSTimeInterval FYClientReconnectInterval;

/**
 Callback for user-defined channel subscriptions.
 */
typedef void(^FYMessageCallback)(NSDictionary *userInfo);


/**
 The FYClient object is used to setup and manage requests to servers using the Bayeux protocol.
 
 This class provides helper methods that simplify the connection, response and subscription handling. The client
 implementation is atleast conditionally compliant by satisfying all MUST or REQUIRED level requirements as specified
 in [The Bayeux Specification](http://svn.cometd.com/trunk/bayeux/bayeux.html).
 */
@interface FYClient : NSObject

/**
 Base URL to which the underlying web socket connection will be connected.
 */
@property (nonatomic, retain, readonly) NSURL *baseURL;

/**
 [FYMessage clientId] which was received by Bayeux handshake.
 */
@property (nonatomic, retain, readonly) NSString *clientId;

/**
 Flag for behavior of connectOnSuccess:.
 
 If property's value is YES, then the client wait for successful connect of the socket connection.
 If property's value is NO, then the client will send the Bayeux handshake message while establishing the
 socket connection and could use an own HTTP-POST connection as documented in the sequence chart.  This can cause
 problems with some server implementations.
 
 Default is YES.
 */
@property (nonatomic, assign) BOOL maySendHandshakeAsync;

/**
 Flag for behavior of connectOnSuccess:.
 
 If property's value is NO, then the client wait for successful confirmation of the Bayeux connect message and
 then executes the success block. If property's value is YES, the client will execute success block on success of
 the Bayeux handshake message. This can speed up the connection process.
 
 Default is NO.
 */
@property (nonatomic, assign) BOOL awaitOnlyHandshake;

/**
 Check if client is connected
 */
@property (nonatomic, assign, readonly, getter=isConnected) BOOL connected;

/**
 Check if a client is reconnecting, currently.
 
 If there was already a reconnect, which failed on socket layer (or on any other way without receiving a Bayeux
 connect answer), then the re-subscript success handlers can got chained internally. This can cause multiple channel
 subscription messages. These will not be neccessary and would not cause any errors, but they could cause some more
 latency, theoretically. This is avoided by using this property value, internally.
 */
@property (nonatomic, assign, readonly, getter=isReconnecting) BOOL reconnecting;

/**
 Delegate to handle state transitions and errors, should be set direct after initialization of an <FYClient>
 object.
 */
@property (nonatomic, assign) id<FYClientDelegate> delegate;

/**
 Dispatch queue on which delegate calls are executed.
 */
@property (nonatomic) dispatch_queue_t delegateQueue;

/**
 Dispatch queue on which callback block call are executed.
 */
@property (nonatomic) dispatch_queue_t callbackQueue;

/**
 All subscripted channels
 */
@property (nonatomic, copy, readonly) NSArray *subscriptedChannels;

/**
 Underlying web socket implementation
 */
@property (nonatomic, retain, readonly) SRWebSocket* webSocket;

/**
 Initializer
 
 Initialize a new instance with a fixed base URL.
 
 @param baseURL  server URL whose scheme has to fulfill ```/ws(s)?|http(s)?/```.
 */
- (id)initWithURL:(NSURL *)baseURL;

/**
 Calling persist will cause that the client must not be retained by yourself until a explicit disconnect occurs.
 */
- (id)persist;

/**
 Open a web socket connection and connect the receiver to its bound server.
 
 This will be used after an instance of 'FYClient' was initialized and its 'delegate' property was set, e.g:
 
     FYClient* client = [[FYClient alloc] initWithURL:[NSURL URLWithString:"ws://localhost:8000/faye"]];
     client.delegate = self;
     [client connect];
 
 
 Internal the following steps will be done to establish a connection:
 
    ┌──────────────────────────────────────────────────────────────────────────────────────────┐
    │                                                                                          │
    │          BC ----------- I ----------- U ----------- P ----------- O ----------- BS       │
    │           ┆             ┆             ┆             ┆             ┆             ┆        │
    │    (1)    ╟───close────>║             ┆             ┆             ┆             ┆        │
    │           ║             ~ wait        ┆             ┆             ┆             ┆        │
    │           ║         <───╢             ┆             ┆             ┆             ┆        │
    │    (2)    ╟─reset       ┆             ┆             ┆             ┆             ┆        │
    │           ║             ┆             ┆             ┆             ┆             ┆        │
    │    (3)    ╟╌╌╌╌open╌╌╌╌>║             ┆             ┆             ┆             ┆        │
    │           ║             ╟╌╌╌╌╌╌╌╌╌╌╌╌req(upgrade):GET╌╌╌╌╌╌╌╌╌╌╌╌>║             ┆        │
    │           ║             ║             ┆             ┆             ║             ┆        │
    │           ║             ║             ┆             ┆             ║             ┆        │
    │           ║             ║             ┆             ┆             ║             ┆        │
    │    (6)    ╟╌╌╌╌╌╌╌╌m(handshk)╌╌╌╌╌╌╌╌>║             ┆             ║             ┆        │
    │           ║             ║             ╟╌╌╌req(m(handshk)):POST╌╌>╓║             ┆        │
    │           ║             ║             ║             ┆            ╟╫─m(handshk)─>║        │
    │           ║             ║             ║             ┆            ║║             ║        │
    │           ~             ~             ~             ~             ~             ~ wait   │
    │           ║             ║             ║             ┆            ║║             ║        │
    │    (4)    ║             ╟<╌╌╌╌╌╌╌╌╌╌╌res(upgrade):101╌╌╌╌╌╌╌╌╌╌╌╌║╢             ║        │
    │           ║             ║             ║             ┆            ║║             ║        │
    │    (5)    ╟<──confirm───╢             ║             ┆            ║║             ║        │
    │           ║             ║             ║             ┆            ║║             ║        │
    │           ║             ║             ║             ┆            ╟<──m(success)─╢        │
    │           ║             ║             ╟<╌╌res(m(handshk,1)):200╌╌╢║             ║        │
    │    (7)    ╟<───────m(success)─────────╢             ┆            ╙║             ║        │
    │           ║             ║             ┆             ┆             ║             ║        │
    │    (8)    ╟─m(connect)─>║             ┆             ┆             ║             ┆        │
    │           ║             ╟╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌m(connect)╌╌╌╌╌╌╌╌╌╌╌╌╌╌>║             ┆        │
    │           ║             ║             ┆             ┆             ╟─m(connect)─>║        │
    │           ║             ║             ┆             ┆             ║             ║        │
    │           ~             ~             ~             ~             ~             ~ wait   │
    │           ║             ║             ┆             ┆             ║             ║        │
    │           ║             ║             ┆             ┆             ╟<─m(success)─╢        │
    │           ║             ╟<╌╌╌╌╌╌╌╌╌╌╌╌╌╌m(connect,1)╌╌╌╌╌╌╌╌╌╌╌╌╌╌╢             ║        │
    │    (9)    ╟<─m(success)─╢             ┆             ┆             ║             ║        │
    │           ║             ║             ┆             ┆             ║             ║        │
    │                                                                                          │
    └──────────────────────────────────────────────────────────────────────────────────────────┘
 
 #### Entities:
 
    BC: Bayeux client
    I:  Web socket implementation (SocketRocket)
    U:  HTTP User Agent implementation (Foundation)
    P:  Proxy
    O:  Origin server
    BS: Bayeux server
     :  No one
 
 #### Graphical syntax:
 
    ╌╌╌>: Asynchronous
    ───>: Synchronous
    ┆:    No process
    ║:    Process
 
 
 #### Steps:
 
 1. Close any existing web socket connection
 
 2. Reset client's internal state information
 
 3. Open a new web socket connection with underlying implementation
 
       GET /faye HTTP/1.1
       Host: <HOST>:<PORT>
       Origin: http://<HOST>:<PORT>
       Sec-WebSocket-Key: YSBrZXkgdG9rZW4=
       Upgrade: websocket
       Connection: Upgrade
       Sec-WebSocket-Version: <VERSION>
 
 4. Underlying web socket implementation await that connection was opened by origin server
 
       HTTP/1.1 101 Switching Protocols
       Upgrade: websocket
       Connection: Upgrade
       Sec-WebSocket-Accept: c29tZSBhY2NlcHQgdG9rZW4=
 
 5. Client await confirmation that connection was opened by underlying web socket implementation
 
       [SRWebSocketDelegate webSocketDidOpen:]
 
 6. Send handshake to the Bayeux server
 
       [{ "channel": "handshake", "supportedConnectionTypes": [ "websocket", ...
 
 7. Await successful confirmation of handshake message
 
       [{ "channel": "handshake", "successful": 1, ...
 
 8. Send connect when 5. and 7. were confirmed. (They run in parallel.)
 
       [{ "channel": "connect", "connectionType": "websocket", ...
 
 9. Await successful confirmation of connect message
 
       [{ "channel": "connect", "successful": 1, ...
 */
- (void)connect;

/**
 Open a web socket connection and connect the receiver to its bound server with an extension object.
 
 Extended variant of `connect`.
 
 @param extension  An extension as an arbitrary JSON encodeable object according to [`ext` documentation][45].
 If argument is 'nil', then this method will do the same as [FYClient connect].
 */
- (void)connectWithExtension:(NSDictionary *)extension;

/**
 Open a web socket connection and connect the receiver to its bound server with an extension object and a block which
 is executed on success.
 
 Extended variant of `connect`.
 
 @param block      Will be asynchronically called on success of operation. Receiver is given as argument to the block.
 Will be executed on callbackQueue.
 */
- (void)connectOnSuccess:(void(^)(FYClient *))block;

/**
 Open a web socket connection and connect the receiver to its bound server with an extension object and a block which
 is executed on success.
 
 Extended variant of `connect`.
 
 @param extension  An extension as an arbitrary JSON encodeable object according to 
 If argument is 'nil', then this method will do the same as [FYClient connectOnSuccess:].
 
 @param block      Will be asynchronically called on success of operation. Receiver is given as argument to the block.
 Will be executed on callbackQueue.
 */
- (void)connectWithExtension:(NSDictionary *)extension onSuccess:(void(^)(FYClient *))block;

/**
 Disconnect an instance from its bound server and closes its underlying web socket connection.
 */
- (void)disconnect;

/**
 Reconnect could be used to try to establish the connection state before the last disconnect.
 This includes to re-subscript all prior subscripted channels. The channel callbacks are kept.
 
 The reconnect implementation is using connectWithExtension:onSuccess:, internally. It uses the given
 connectionExtension. On success it will re-subscript all prior subscripted channels (as returned by
 subscriptedChannels). The same channel callbacks will be kept. But this implementation will not re-execute the
 connect success handler, which was maybe given originally. If you would do a repetive initialization, which is not
 bound to incoming messages, then you should place it in your implementation of [FYClientDelegate clientConnected:]
 which is guarenteed to be called on each connect, also on reconnect.
 */
- (void)reconnect;

/**
 Register interest in a channel and request that messages published to that channel are delivered to receiver.
 
 @param channel    Subscribe to a channel name or a channel pattern
 
 @param callback   Will be called on receive of a message on given `channel` on main thread
 */
- (void)subscribeChannel:(NSString *)channel callback:(FYMessageCallback)callback;

/**
 Register interest in a channel and request that messages published to that channel are delivered to receiver.
 
 @param channel    Subscribe to a channel name or a channel pattern
 
 @param callback   Will be called on receive of a message on given `channel` on main thread
 
 @param extension  An extension as an arbitrary JSON encodeable object according to [`ext` documentation][45].
 */
- (void)subscribeChannel:(NSString *)channel callback:(FYMessageCallback)callback extension:(NSDictionary *)extension;

/**
 Register interest in a channel and request that messages published to that channel are delivered to receiver.
 
 @param channels   Subscribe to an array of channel names and channel patterns
 
 @param callback   Will be called on receive of a message on given 'channel' on main thread
 */
- (void)subscribeChannels:(NSArray *)channels callback:(FYMessageCallback)callback;

/**
 Register interest in a channel and request that messages published to that channel are delivered to receiver.
 
 @param channels   Subscribe to an array of channel names and channel patterns
 
 @param callback   Will be called on receive of a message on given 'channel' on main thread
 
 @param extension  An extension as an arbitrary JSON encodeable object according to [`ext` documentation][45].
 */
- (void)subscribeChannels:(NSArray *)channels callback:(FYMessageCallback)callback extension:(NSDictionary *)extension;

/**
 Cancel interest in a channel and request that messages published to that channel are not delivered.
 
 @param channel    Subscribe to a channel name or a channel pattern
 */
- (void)unsubscribeChannel:(NSString *)channel;

/**
 Cancel interest in a channel and request that messages published to that channel are not delivered.
 
 @param channels   Subscribe to an array of channel names and channel patterns
 */
- (void)unsubscribeChannels:(NSArray *)channels;

/**
 Cancel interest in all channels and request that messages published to that channels are not delivered.
 */
- (void)unsubscribeAll;

/**
 Publish events on a channel by sending event messages.
 
 A publish message COULD with this implementation NOT be sent from an unconnected client.
 
 @param userInfo   The message as an arbitrary JSON encodeable object
 
 @param channel    Subscribe to a channel name or a channel pattern
 */
- (void)publish:(NSDictionary *)userInfo onChannel:(NSString *)channel;

/**
 Publish events on a channel by sending event messages with an extension object.
 
 A publish message COULD with this implementation NOT be sent from an unconnected client.
 
 @param userInfo   The message as an arbitrary JSON encodeable object
 
 @param channel    Subscribe to a channel name or a channel pattern
 
 @param extension  An extension as an arbitrary JSON encodeable object according to [`ext` documentation][45].
 */
- (void)publish:(NSDictionary *)userInfo onChannel:(NSString *)channel withExtension:(NSDictionary *)extension;

@end
