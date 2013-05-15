//
//  FYClient.m
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

#import <CFNetwork/CFNetwork.h>
#import <objc/runtime.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <sys/errno.h>
#import <UIKit/UIKit.h>
#import "FYClient.h"
#import "FYActor.h"
#import "SocketShuttle_Private.h"


//#define FYDebug 1

#ifdef FYDebug
    #define FYLog(...) NSLog(__VA_ARGS__)
#else
    #define FYLog(...) 
#endif


const NSTimeInterval FYClientReconnectInterval  = 1;

NSString *const FYWorkerQueueName = @"com.paij.SocketShuttle.FYClient";

const struct FYMetaChannels FYMetaChannels = {
    .Handshake   = @"/meta/handshake",
    .Connect     = @"/meta/connect",
    .Disconnect  = @"/meta/disconnect",
    .Subscribe   = @"/meta/subscribe",
    .Unsubscribe = @"/meta/unsubscribe",
};

const struct FYConnectionTypes FYConnectionTypes = {
    .LongPolling            = @"long-polling",
    .CallbackPolling        = @"callback-polling",
    .WebSocket              = @"websocket",
};

NSArray *FYSupportedConnectionTypes() {
    return @[FYConnectionTypes.WebSocket];
}

const NSUInteger FYClientStateSetIsConnecting = (1<<2);
typedef NS_ENUM(NSUInteger, FYClientState) {
    FYClientStateDisconnected    = 0,
    FYClientStateHandshaking     = FYClientStateSetIsConnecting | 1,
    FYClientStateWillSendConnect = FYClientStateSetIsConnecting | 2,
    FYClientStateConnecting      = FYClientStateSetIsConnecting | 3,
    FYClientStateConnected       = (1<<3),
    FYClientStateDisconnecting   = (1<<4),
};



/*
 Adapt SystemConfiguration rechability's callback as C function pointer to ObjC blocks to pass an inline block handler.
 This has the advantage that the code don't has to be scattered over the whole file.
 */
typedef void(^FYReachabilityBlock)(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags);

static void FYReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
    FYReachabilityBlock handler = ((__bridge_transfer typeof(FYReachabilityBlock))info);
    handler(target, flags);
};



/**
 Blocks needs to be copied, when stored. Because you can use one single block as callback for multiple subscripted
 channels and we don't want to copy the block for each channel, use a wrapper object, which copy the block once and
 which will be released first, if all references, which are held each by a channel, were released by unsubscripting
 all these channels.
 */
@interface FYMessageCallbackWrapper : NSObject

/**
 Wrapper block callback.
 */
@property (nonatomic, copy) FYMessageCallback callback;

/**
 Channel extension used to subscribe.
 */
@property (nonatomic, retain) NSDictionary *extension;

/**
 Initializer
 
 @param  callback  The block, which should be wrapped.
 
 @param extension  An extension as an arbitrary JSON encodeable object according to [`ext` documentation][45].
 */
- (id)initWithCallback:(FYMessageCallback)callback extension:(NSDictionary *)extension;

@end


@implementation FYMessageCallbackWrapper

- (id)initWithCallback:(FYMessageCallback)callback extension:(NSDictionary *)extension {
    self = [super init];
    if (self) {
        self.callback = callback;
        self.extension = extension;
    }
    return self;
}

@end



/**
 An instance of FYDelegateProxy is used internally in FYClient to dispatch calls to its [delegate]([FYClient delegate]).
 
 A `NSProxy` subclass `FYDelegateProxy` is used in `FYClient` as property [delegateProxy]([FYClient delegateProxy]) to
 dispatch calls to the delegate property. This is used to don't have to think about non-implemented optional protocol
 methods. All declared selectors could be invoked and are forwared to the real delegate implementation stored in
 `proxiedObject` property of `FYDelegateProxy`. So the getter and setter implementation of the property `delegate` of
 `FYClient` have to return / mutate ```self.delegateProxy.proxiedObject```.
 
 So instead of writing a lot of repeative code like:
 
    if ([self.delegate respondsToSelector:@selector(client:didFoo:)]) {
        [self.delegate client:self didFoo:foo];
    }
 
 You can simply write your code like:
 
    [self.delegateProxy client:self didFoo:foo];
 
 This won't raise any "selector not found" exception, if this selector is optional and not implemented.
 */
@interface FYDelegateProxy : NSProxy<FYClientDelegate>

/**
 Dispatch queue on which delegate calls are executed.
 */
@property (nonatomic, retain) dispatch_queue_t delegateQueue;

/**
 The proxied object.
 */
@property (nonatomic, assign) id<NSObject,FYClientDelegate> proxiedObject;

@end


@implementation FYDelegateProxy

- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector {
	NSMethodSignature *signature = [_proxiedObject.class instanceMethodSignatureForSelector:selector];
	if (!signature) {
        // methodSignatureForSelector: is called when a compiled definition for the selector cannot be found.
        // If this method returns nil, a "selector not found" exception is raised.
        // The string argument to signatureWithObjCTypes: outlines the return type and arguments to the message.
        // To return a dud `NSMethodSignature`, pretty much any signature will suffice. Since the forwardInvocation:
        // call will do nothing if the delegate does not respond to the selector, the dud `NSMethodSignature` simply
        // gets us around the exception.
        // @see http://borkware.com/rants/agentm/elegant-delegation/
		signature = [NSMethodSignature signatureWithObjCTypes:"@^v^c"];
	}
	return signature;
}

- (void)forwardInvocation:(NSInvocation*)invocation {
    // Because there seems a delay when dispatching arguments async by using GCD arguments need to be retained manually
    // so that they don't get released before the invocation was forwarded. This would cause an EXC_BAD_ACCESS(code=2).
    // This could also occur if you are debugging with breakpoints...
    [invocation retainArguments];
    
    FYLog(@"[%@] %@", self.class, NSStringFromSelector(invocation.selector));
    
    if ([_proxiedObject respondsToSelector:invocation.selector]) {
        dispatch_async(_delegateQueue, ^{
            [invocation invokeWithTarget:self.proxiedObject];
         });
    }
}

@end


/**
 Internal category for 'FYClient' to replace host name with arguments from `hosts` advice, to fulfill this advice on
 connection problems.
 */
@interface NSURL (ReplaceHost)

/**
 Replaces the host in an URL with another host.
 
 @param scheme  The scheme of the new URL conforming to RFC 1808.
 
 @param host    The host of the new URL conforming to RFC 1808.
 */
- (NSURL *)URLWithScheme:(NSString *)scheme host:(NSString *)host;

@end


@implementation NSURL (ReplaceHost)

- (NSURL *)URLWithScheme:(NSString *)scheme host:(NSString *)host {
    NSMutableArray *components = [NSMutableArray new];
    [components addObject:scheme];
    [components addObject:@"://"];
    if (self.user) {
        [components addObject:self.user];
        if (self.password) {
            [components addObject:self.password];
        }
        [components addObject:@"@"];
    }
    [components addObject:host];
    if (self.port) {
        [components addObject:@":"];
        [components addObject:self.port];
    }
    [components addObject:[self.path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    if (self.query) {
        [components addObject:@"?"];
        [components addObject:self.query];
    }
    if (self.fragment) {
        [components addObject:@"#"];
        [components addObject:self.fragment];
    }
    return [self.class URLWithString:[components componentsJoinedByString:@""]];
}

@end



/*
 Private interface
 */
@interface FYClient () <SRWebSocketDelegate, NSURLConnectionDataDelegate>

// External readonly properties redefined as readwrite
@property (nonatomic, retain, readwrite) NSURL *baseURL;
@property (nonatomic, retain, readwrite) NSString *clientId;
@property (nonatomic, retain, readwrite) SRWebSocket *webSocket;
@property (nonatomic, retain, readwrite) id persist;
@property (nonatomic, assign, readwrite) BOOL reconnecting;

// URL with NSURLConnection-compatible scheme
@property (nonatomic, retain) NSURL *httpBaseURL;

// Internal used properties only
@property (nonatomic, retain) NSMutableDictionary *metaChannelActors;

@property (nonatomic, assign) FYClientState state;
@property (nonatomic, assign) BOOL shouldReconnectOnDidBecomeActive;

@property (nonatomic, retain) NSString *connectionType;
@property (nonatomic, retain) NSDictionary *connectionExtension;
@property (nonatomic, retain, readwrite) NSMutableDictionary *channels;

@property (nonatomic, retain) FYDelegateProxy *delegateProxy;
@property (nonatomic, retain) dispatch_queue_t workerQueue;

// TODO: Enumerate hosts
//@property (nonatomic, retain) NSMutableArray *alternateHosts;
//@property (nonatomic, retain) NSMutableArray *triedHosts;

// UIApplication state notification handler
- (void)applicationWillResignActive:(NSNotification *)note;
- (void)applicationDidBecomeActive:(NSNotification *)note;

// Protected connection status methods
- (void)handshake;
- (BOOL)isConnecting;

// SRWebSocket facade methods
- (void)openSocketConnection;
- (void)closeSocketConnection;
- (void)sendSocketMessage:(NSDictionary *)message;

// NSURLConnection facade methods
- (void)sendHTTPMessage:(NSDictionary *)message;

// Communication helper functions
- (void)handlePOSIXError:(NSError *)error;
- (void)sendMessage:(NSDictionary *)message;
- (NSString *)generateMessageId;

// Bayeux protocol functions
- (void)sendHandshake;
- (void)sendConnect;
- (void)sendDisconnect;
- (void)sendSubscribe:(id)channel withExtension:(NSDictionary *)extension;
- (void)sendUnsubscribe:(id)channel;
- (void)sendPublish:(NSDictionary *)userInfo onChannel:(NSString *)channel withExtension:(NSDictionary *)extension;

// Bayeux protocol responses handlers
- (void)handleResponse:(NSString *)message;
- (void)client:(FYClient *)client receivedHandshakeMessage:(FYMessage *)message;
- (void)client:(FYClient *)client receivedConnectMessage:(FYMessage *)message;
- (void)client:(FYClient *)client receivedDisconnectMessage:(FYMessage *)message;
- (void)client:(FYClient *)client receivedSubscribeMessage:(FYMessage *)message;
- (void)client:(FYClient *)client receivedUnsubscribeMessage:(FYMessage *)message;

// JSON serialization & deserialization
- (NSString *)stringBySerializingObject:(NSObject *)object;
- (NSData *)dataBySerializingObject:(NSObject *)object;
- (id)deserializeString:(NSString *)string;
- (id)deserializeData:(NSData *)data;

// General helper
- (void)performBlock:(void(^)(FYClient *))block afterDelay:(NSTimeInterval)delay;
- (void)chainActorForMetaChannel:(NSString *)channel onceWithActorBlock:(FYActorBlock)block;

@end


@implementation FYClient

// Exclude properties from automatic synthesization
@dynamic connected;
@dynamic delegateQueue;

- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"Don't use [%@ %@]You must use the designated initializer: %@.",
                                           self.class, NSStringFromSelector(_cmd), NSStringFromSelector(@selector(initWithURL:))]
                                 userInfo:nil];
}

- (void)dealloc {
    // Explicitly assign nil to provoke memory management
    self.callbackQueue = nil;
    self.delegateQueue = nil;
    self.workerQueue   = nil;
}

- (id)initWithURL:(NSURL *)baseURL {
    self = [super init];
    if (self) {
        // Validate and set URL
        NSParameterAssert(baseURL);
        NSString *scheme = baseURL.scheme.lowercaseString;
        NSParameterAssert([scheme isEqualToString:@"ws"] || [scheme isEqualToString:@"wss"] ||
                          [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]);
        self.baseURL = baseURL;
        
        // Transform URL to a HTTP URL if needed
        self.httpBaseURL = [scheme hasPrefix:@"http"]
            ? baseURL
            : [baseURL URLWithScheme:[scheme isEqualToString:@"wss"] ? @"https" : @"http" host:baseURL.host];
        
        // This must be done before delegateQueue was set.
        self.delegateProxy = [FYDelegateProxy alloc]; // yes - there is no init ;)
        
        // Init worker queue
        NSString *workerQueueName = [FYWorkerQueueName stringByAppendingFormat:@"_%d", (int)self];
        const char *workerQueueChars = [workerQueueName cStringUsingEncoding:NSASCIIStringEncoding];
        self.workerQueue = dispatch_queue_create(workerQueueChars, NULL);
        
        // Init returning queues
        self.delegateQueue = dispatch_get_main_queue();
        self.callbackQueue = dispatch_get_main_queue();
        
        // Init collections
        self.channels = [NSMutableDictionary new];
        
        // Init state properties
        self.state = FYClientStateDisconnected;
        self.shouldReconnectOnDidBecomeActive = NO;
        
        // Init connection behavior flags
        self.maySendHandshakeAsync = YES;
        self.awaitOnlyHandshake    = NO;
        
        // Bind own message handler selectors dynamically to meta channel names
        id<FYActor>(^makeActor)(SEL) = ^id<FYActor>(SEL selector){
            return [[FYSelTargetActor alloc] initWithTarget:self selector:selector];
         };
        
        self.metaChannelActors = @{
             FYMetaChannels.Handshake:   makeActor(@selector(client:receivedHandshakeMessage:)),
             FYMetaChannels.Connect:     makeActor(@selector(client:receivedConnectMessage:)),
             FYMetaChannels.Disconnect:  makeActor(@selector(client:receivedDisconnectMessage:)),
             FYMetaChannels.Subscribe:   makeActor(@selector(client:receivedSubscribeMessage:)),
             FYMetaChannels.Unsubscribe: makeActor(@selector(client:receivedUnsubscribeMessage:)),
         }.mutableCopy;
        
        // Observe UIApplication notifications
        NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [center addObserver:self selector:@selector(applicationDidBecomeActive:)  name:UIApplicationDidBecomeActiveNotification  object:nil];
    }
    return self;
}

- (id)persist {
    return (self.persist = self);
}


#pragma mark - Custom delegate getter and setter forwards to delegateProxy

- (void)setDelegate:(id<FYClientDelegate>)delegate {
    self.delegateProxy.proxiedObject = delegate;
}

- (id<FYClientDelegate>)delegate {
    return self.delegateProxy.proxiedObject;
}

- (void)setDelegateQueue:(dispatch_queue_t)delegateQueue {
    if (delegateQueue) {
        fy_dispatch_retain(delegateQueue);
    }
    NSAssert(self.delegateProxy, @"Delegate proxy has to be initialized before delegateQueue can be set.");
    if (_callbackQueue) {
        fy_dispatch_release(_delegateQueue);
    }
    self.callbackQueue = delegateQueue;
    self.delegateProxy.delegateQueue = delegateQueue;
}

- (dispatch_queue_t)delegateQueue {
    return self.delegateProxy.delegateQueue;
}


#pragma mark - Compatiblity to versions below iOS 6.1, where ARC doesn't support automatic dispatch_retain & dispatch_release

- (void)setCallbackQueue:(dispatch_queue_t)callbackQueue {
    if (callbackQueue) {
        fy_dispatch_retain(callbackQueue);
    }
    if (_callbackQueue) {
        fy_dispatch_release(_callbackQueue);
    }
    self.callbackQueue = callbackQueue;
}


#pragma mark - UIApplication state notification handlers

- (void)applicationWillResignActive:(NSNotification *)note {
    self.shouldReconnectOnDidBecomeActive = self.isConnected || self.isConnecting;
    [self disconnect];
}

- (void)applicationDidBecomeActive:(NSNotification *)note {
    if (self.shouldReconnectOnDidBecomeActive) {
        // This is needed if the client is initialized before application did become active,
        // typically this will be [UIApplicationDelegate application:didFinishLaunchingWithOptions:]
        [self reconnect];
    }
}


#pragma mark - Public connection status methods

- (void)connect {
    [self connectWithExtension:nil];
}

- (void)connectOnSuccess:(void(^)(FYClient *))block; {
    [self connectWithExtension:nil onSuccess:block];
}

- (void)connectWithExtension:(NSDictionary *)extension {
    [self connectWithExtension:extension onSuccess:nil];
}

- (void)connectWithExtension:(NSDictionary *)extension onSuccess:(void(^)(FYClient *))block; {
    self.connectionExtension = extension;
    
    if (block) {
        NSString* channel = FYMetaChannels.Connect;
        if (self.awaitOnlyHandshake) {
            channel = FYMetaChannels.Handshake;
        }
        
        // Swizzle actor:
        // This will even ensure that if the connect fails or a disconnect occurs before Bayeux connect was confirmed by
        // by the server the original success block will be called exactly once on success.
        [self chainActorForMetaChannel:channel onceWithActorBlock:^(FYClient *self, FYMessage *message) {
            // First argument is named self, because it MUST be the same as the receiver in the outer scope, and we don't
            // want to cause retain cycles by capturing self strongly in this block. Syntax hightlighting stays pretty
            // and no additional `__weak` var is needed.
            
            // Execute success block
            dispatch_async(self.callbackQueue, ^{
                block(self);
             });
         }];
    }
    
    // Connect now
    dispatch_async(self.workerQueue, ^{
        [self openSocketConnection];
     });
    
    if (self.maySendHandshakeAsync) {
        // Do the handshake parallel to opening socket connection on an own URL request
        dispatch_async(self.workerQueue, ^{
            [self handshake];
         });
    }
}

- (void)disconnect {
    self.persist = nil;
    [self sendDisconnect];
}

- (void)reconnect {
    // Save current channels
    NSMutableDictionary* channels = self.channels.mutableCopy;
    [self connectWithExtension:self.connectionExtension onSuccess:self.isReconnecting ? nil : ^(FYClient *self) {
        // Re-subscript to channels on server-side
        self.channels = channels;
        for (NSString* channel in channels) {
            // Send subscribe directly, without unboxing and re-boxing FYMessageCallbacks
            [self sendSubscribe:channel withExtension:[channels[channel] extension]];
        }
        
        self.reconnecting = NO;
     }];
    self.reconnecting = YES;
}

- (BOOL)isConnected {
    return self.state == FYClientStateConnected;
}

- (BOOL)isConnecting {
    return self.state & FYClientStateSetIsConnecting;
}

- (NSArray *)subscriptedChannels {
    return self.channels.allKeys;
}


#pragma mark Protected connection status methods

- (void)handshake {
    self.clientId = nil;
    [self sendHandshake];
}


#pragma mark - Channel subscription

- (void)subscribeChannel:(NSString *)channel callback:(FYMessageCallback)callback {
    [self subscribeChannel:channel callback:callback extension:nil];
}

- (void)subscribeChannel:(NSString *)channel callback:(FYMessageCallback)callback extension:(NSDictionary *)extension {
    self.channels[channel] = [[FYMessageCallbackWrapper alloc] initWithCallback:callback extension:extension];
    [self sendSubscribe:channel withExtension:extension];
}

- (void)subscribeChannels:(NSArray *)channels callback:(FYMessageCallback)callback {
    [self subscribeChannels:channels callback:callback extension:nil];
}

- (void)subscribeChannels:(NSArray *)channels callback:(FYMessageCallback)callback extension:(NSDictionary *)extension {
    FYMessageCallbackWrapper *wrapper = [[FYMessageCallbackWrapper alloc] initWithCallback:callback extension:extension];
    for (NSString* channel in channels) {
        self.channels[channel] = wrapper;
    }
    [self sendSubscribe:channels withExtension:extension];
}

- (void)unsubscribeChannel:(NSString *)channel {
    [self.channels removeObjectForKey:channel];
    [self sendUnsubscribe:channel];
}

- (void)unsubscribeChannels:(NSArray *)channels {
    [self.channels removeObjectsForKeys:channels];
    [self sendUnsubscribe:channels];
}

- (void)unsubscribeAll {
    for (NSString* channelName in self.channels) {
        [self sendUnsubscribe:channelName];
    }
}


#pragma mark - Publish on channel

- (void)publish:(NSDictionary *)userInfo onChannel:(NSString *)channel {
    [self sendPublish:userInfo onChannel:channel withExtension:nil];
}

- (void)publish:(NSDictionary *)userInfo onChannel:(NSString *)channel withExtension:(NSDictionary *)extension {
    [self sendPublish:userInfo onChannel:channel withExtension:extension];
}


#pragma mark - SRWebSocket facade methods

- (void)openSocketConnection {
    // Reset existing connection state information
    self.clientId = nil;
    [self.channels removeAllObjects];
    
    // Clean up any existing socket
    self.webSocket.delegate = nil;
    [self.webSocket close];
    
    // Init a new socket
    self.webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:self.baseURL]];
    self.webSocket.delegate = self;
    
    // Let's respond the socket on our workerQueue, we will dispatch one
    // our delegate / callback queues for our own.
    self.webSocket.delegateDispatchQueue = self.workerQueue;
    
    [self.webSocket open];
}

- (void)closeSocketConnection {
    [self.webSocket close];
}

- (void)sendSocketMessage:(NSDictionary *)message {
    dispatch_async(self.workerQueue, ^{
        NSString *serializedMessage = [self stringBySerializingObject:message];
        if (serializedMessage) {
            if (self.webSocket.readyState == SR_OPEN) {
                FYLog(@"Send: %@", message);
                [self.webSocket send:serializedMessage];
            } else {
                NSError *error = [NSError errorWithDomain:FYErrorDomain code:FYErrorSocketNotOpen userInfo:@{
                     NSLocalizedDescriptionKey:        @"The socket connection is not open, but required to be opened.",
                     NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Could not send message %@", message],
                 }];
                [self.delegateProxy client:self failedWithError:error];
            }
        }
     });
}


#pragma mark - SRWebSocketDelegate's implementation

- (void)webSocketDidOpen:(SRWebSocket *)aWebSocket {
    if (self.maySendHandshakeAsync) {
        if (self.state == FYClientStateWillSendConnect) {
            [self sendConnect];
        }
    } else {
        [self handshake];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(NSString *)message {
    [self handleResponse:message];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    self.state = FYClientStateDisconnected;
    
    NSError* error;
    if (!wasClean) {
        error = [NSError errorWithDomain:FYErrorDomain code:FYErrorSocketClosed userInfo:@{
             NSLocalizedDescriptionKey:        @"The socket connection was closed.",
             NSLocalizedFailureReasonErrorKey: reason ?: @"Unknown",
         }];
    } else {
        FYLog(@"Clean exit");
    }
    [self.delegateProxy clientDisconnected:self withMessage:nil error:error];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        [self handlePOSIXError:error];
    }
    [self.delegateProxy client:self failedWithError:error];
}


#pragma mark - NSURLConnection facade

- (void)sendHTTPMessage:(NSDictionary *)message {
    dispatch_async(self.workerQueue, ^{
        NSData *serializedMessage = [self dataBySerializingObject:@[message]];
        if (serializedMessage) {
            FYLog(@"Send: %@", message);
            
            // Initialize a new URL request
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.httpBaseURL];
            request.HTTPMethod  = @"POST";
            request.HTTPBody    = serializedMessage;
            
            // Set HTTP headers
            NSDictionary *headers = @{
                @"Content-Type": @"application/json",
             };
            // TODO Add here a delegate method to further initialize requests header fields for authorization
            // with inout &headers
            for (NSString *headerField in headers) {
                [request addValue:headers[headerField] forHTTPHeaderField:headerField];
            }
            
            // Configure request options
            request.HTTPShouldUsePipelining = YES;
            request.cachePolicy             = NSURLRequestReloadIgnoringLocalCacheData;
            // Implicitly needed defaults
            //request.allowsCellularAccess    = YES;
            //request.HTTPShouldHandleCookies = YES;
            
            // Send request
            NSURLConnection *connection;
            connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
            [connection scheduleInRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
            [connection start];
        }
    });
}

#pragma mark - NSURLConnectionDataDelegate's implementation

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSAssert([response isKindOfClass:NSHTTPURLResponse.class], @"Expected only HTTP responses!");
    objc_setAssociatedObject(connection, (__bridge const void *)(NSHTTPURLResponse.class), response, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    dispatch_async(self.workerQueue, ^{
        NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSHTTPURLResponse *response = objc_getAssociatedObject(connection, (__bridge const void *)(NSHTTPURLResponse.class));
        if (response.statusCode != 200) {
            NSError *error = [NSError errorWithDomain:FYErrorDomain code:FYErrorHTTPUnexpectedStatusCode userInfo:@{
                NSLocalizedDescriptionKey:        @"The HTTP request returned with an unexpected status code.",
                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Received unexpected response with "
                                                   "status code %d with content: %@.", response.statusCode, message]
             }];
            [self.delegateProxy client:self failedWithError:error];
        } else {
            [self handleResponse:message];
        }
     });
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.delegateProxy client:self failedWithError:error];
}


#pragma mark - Communication helper functions

- (void)handlePOSIXError:(NSError *)error {
    NSParameterAssert([error.domain isEqualToString:NSPOSIXErrorDomain]);
    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        switch (error.code) {
            case ENETDOWN:       // Network is down
            case ENETUNREACH:    // Network is unreachable
            case EHOSTDOWN:      // Host is down
            case EHOSTUNREACH:   // No route to host
            {
                // Use SystemConfiguration to await a network connection
                __block SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithName(NULL, self.baseURL.host.UTF8String);
                SCNetworkReachabilityContext context = {
                    .info = (__bridge_retained void *)[^(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags){
                        if (!(flags & kSCNetworkReachabilityFlagsReachable)
                            || (   flags & kSCNetworkReachabilityFlagsConnectionRequired
                                && flags & kSCNetworkReachabilityFlagsTransientConnection
                            )) {
                            return;
                        }
                        
                        // Tear down
                        SCNetworkReachabilitySetCallback(ref, NULL, NULL);
                        SCNetworkReachabilitySetDispatchQueue(ref, NULL);
                        CFRelease(ref);
                        ref = nil;
                        
                        // Try to reconnect
                        [self performBlock:^(FYClient *client) {
                            [self reconnect];
                         } afterDelay:FYClientReconnectInterval];
                    } copy],
                 };
                
                SCNetworkReachabilitySetCallback(ref, FYReachabilityCallback, &context);
                SCNetworkReachabilitySetDispatchQueue(ref, self.workerQueue);
                break;
            }
                
            case ECONNRESET:     // Connection reset by peer
            case ENOTCONN:       // Socket is not connected
            case ETIMEDOUT:      // Operation timed out
            case ECONNREFUSED:   // Connection refused
                // Try to reconnect
                [self performBlock:^(FYClient *client) {
                    [self reconnect];
                 } afterDelay:FYClientReconnectInterval];
                break;
        }
    }
}

- (void)sendMessage:(NSDictionary *)message {
    if (self.webSocket.readyState == SR_OPEN) {
        [self sendSocketMessage:message];
    } else {
        [self sendHTTPMessage:message];
    }
}

- (NSString *)generateMessageId {
    return [NSString stringWithFormat:@"msg_%.5f_%d", [NSDate.date timeIntervalSince1970], 0];
}


#pragma mark - Bayeux procotol functions

- (void)sendHandshake {
    [self sendMessage:@{
        @"channel":                  FYMetaChannels.Handshake,
        @"version":                  @"1.0",
        @"minimumVersion":           @"1.0beta",
        @"supportedConnectionTypes": FYSupportedConnectionTypes(),
     }];
}

- (void)sendConnect {
    [self sendSocketMessage:@{
        @"channel":        FYMetaChannels.Connect,
        @"clientId":       self.clientId,
        @"connectionType": self.connectionType,
        @"ext":            self.connectionExtension ?: NSNull.null,
     }];
}

- (void)sendDisconnect {
    [self sendSocketMessage:@{
        @"channel":        FYMetaChannels.Disconnect,
        @"clientId":       self.clientId,
     }];
}

- (void)sendSubscribe:(id)channel withExtension:(NSDictionary *)extension {
    [self sendSocketMessage:@{
        @"channel":      FYMetaChannels.Subscribe,
        @"clientId":     self.clientId,
        @"subscription": channel,
        @"ext":          extension ?: NSNull.null
     }];
}

- (void)sendUnsubscribe:(id)channel {
    [self sendSocketMessage:@{
        @"channel":      FYMetaChannels.Unsubscribe,
        @"clientId":     self.clientId,
        @"subscription": channel,
     }];
}

- (void)sendPublish:(NSDictionary *)userInfo onChannel:(NSString *)channel withExtension:(NSDictionary *)extension {
    [self sendSocketMessage:@{
        @"channel":  channel,
        @"clientId": self.clientId,
        @"data":     userInfo,
        @"id":       [self generateMessageId],
        @"ext":      extension ?: NSNull.null
     }];
}


#pragma mark - Bayeux protocol responses handlers

- (void)handleResponse:(NSString *)message {
    id result = [self deserializeString:message];
    if (![result isKindOfClass:NSArray.class]) {
        // Response is malformed
        NSError* error = [NSError errorWithDomain:FYErrorDomain code:FYErrorMalformedJSONData userInfo:@{
            NSLocalizedDescriptionKey:        @"Response is malformed.",
            NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Expected an array of messages, but got %@", result],
         }];
        [self.delegateProxy client:self failedWithError:error];
        return;
    }
    
    NSArray* messages = result;
    for (NSDictionary* userInfo in messages) {
        FYLog(@"handleResponse: %@", userInfo);
        
        // Box in message object to unserialize all fields
        FYMessage *message = [[FYMessage alloc] initWithUserInfo:userInfo];
        
        BOOL handled = NO;
        
        // Check if its a meta channel message, which must be handled.
        for (NSString* channel in self.metaChannelActors) {
            if ([channel isEqualToString:message.channel]) {
                id<FYActor> actor = self.metaChannelActors[channel];
                [actor client:self receivedMessage:message];
                handled = YES;
                break;
            }
        }
        
        if (!handled) {
            if ([message.channel hasPrefix:@"/meta"]) {
                // Unhandled meta channel
                NSError* error = [NSError errorWithDomain:FYErrorDomain code:FYErrorUnhandledMetaChannelMessage userInfo:@{
                    NSLocalizedDescriptionKey:        @"Unhandled meta channel message",
                    NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Unhandled meta channel message on channel '%@'", message.channel],
                 }];
                [self.delegateProxy client:self failedWithError:error];
            } else if (self.channels[message.channel]) {
                // User-defined channel
                if (message.data) {
                    FYMessageCallbackWrapper* wrapper = self.channels[message.channel];
                    dispatch_async(self.callbackQueue, ^{
                        wrapper.callback(message.data);
                     });
                }
            } else {
                // Unexpected channel
                [self.delegateProxy client:self receivedUnexpectedMessage:message];
            }
        }
        
        // Handle advice
        if (message.advice) {
            if (message.advice[@"reconnect"]) {
                [self handleReconnectAdviceOfMessage:message];
            }
        }
    }
}


#pragma mark - Advice handlers

- (void)handleReconnectAdviceOfMessage:(FYMessage *)message {
    if ([message.successful boolValue]) {
        // Don't handle reconnect advice on succesful messages.
        return;
    }
    
    NSString* reconnectAdvice = message.advice[@"reconnect"];
    if ([reconnectAdvice isEqualToString:@"retry"]) {
        // Use delay given by server, if available
        NSTimeInterval delay = FYClientReconnectInterval;
        if (message.advice[@"interval"]) {
            // Interval is given in milliseconds, NSTimeInterval is in seconds.
            delay = [message.advice[@"interval"] doubleValue] / 1000.0;
        }
        [self.delegateProxy clientWasAdvisedToRetry:self retryInterval:&delay];
        if (delay > 0) {
            [self performBlock:^(FYClient *client) {
                [self sendConnect];
             } afterDelay:delay];
        }
    } else if ([reconnectAdvice isEqualToString:@"handshake"]) {
        BOOL retry = NO;
        [self.delegateProxy clientWasAdvisedToHandshake:self shouldRetry:&retry];
        if (retry) {
            [self handshake];
        }
    } else if ([reconnectAdvice isEqualToString:@"none"]) {
        if ([message.subscription isEqualToString:@"connection"]) {
            self.state = FYClientStateDisconnected;
            
            NSError *error = [NSError errorWithDomain:FYErrorDomain code:FYErrorReceivedAdviceReconnectTypeNone userInfo:@{
                NSLocalizedDescriptionKey:        [NSString stringWithFormat:@"Received reconnect advice 'none'."],
                NSLocalizedFailureReasonErrorKey: message.error ?: @"Unknown",
             }];
            [self.delegateProxy clientDisconnected:self withMessage:message error:error];
        }
    }
}


#pragma mark - Channel handlers

- (void)client:(FYClient *)client receivedHandshakeMessage:(FYMessage *)message {
    if ([message.successful boolValue]) {
        self.clientId = message.clientId;
        NSMutableSet *commonSupportedConnectionTypes = [[NSMutableSet alloc] initWithArray:FYSupportedConnectionTypes()];
        [commonSupportedConnectionTypes intersectsSet:[[NSSet alloc] initWithArray:message.supportedConnectionTypes]];
        
        if (!commonSupportedConnectionTypes.count > 0) {
            // No common supported connection type.
            NSError *error = [NSError errorWithDomain:FYErrorDomain code:FYErrorNoCommonSupportedConnectionType userInfo:@{
                NSLocalizedDescriptionKey:        [NSString stringWithFormat:@"Error while trying to connect with host %@",
                                                   self.baseURL.absoluteString],
                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"No common supported connection type. "
                                                   "Server supports the following: %@. Required was one of: %@",
                                                   message.supportedConnectionTypes, FYSupportedConnectionTypes()]
             }];
            [self.delegateProxy clientDisconnected:self withMessage:message error:error];
            return;
        }
        
        if ([commonSupportedConnectionTypes containsObject:FYConnectionTypes.WebSocket]) {
            self.connectionType = FYConnectionTypes.WebSocket;
            if (self.webSocket.readyState == SR_OPEN) {
                [self sendConnect];
            }
        } else {
            NSAssert(@"The implementation of %@ does not handle all of the supported connection types "
                     "(FYSupportedConnectionTypes()=%@)!", NSStringFromSelector(_cmd), FYSupportedConnectionTypes());
        }
    } else {
        // Handshake failed.
        NSError *error = [NSError errorWithDomain:FYErrorDomain code:FYErrorHandshakeFailed userInfo:@{
            NSLocalizedDescriptionKey:        [NSString stringWithFormat:@"Error on handshake with host %@",
                                               self.baseURL.absoluteString],
            NSLocalizedFailureReasonErrorKey: message.error ?: @"Unknown",
         }];
        [self.delegateProxy client:self failedWithError:error];
    }
}

- (void)client:(FYClient *)client receivedConnectMessage:(FYMessage *)message {
    if ([message.successful boolValue]) {
        self.state = FYClientStateConnected;
        [self.delegateProxy clientConnected:self];
    } else {
        self.state = FYClientStateDisconnected;
        
        // Web socket connection was established, but Bayeux connection failed.
        NSError *error = [NSError errorWithDomain:FYErrorDomain code:FYErrorConnectFailed userInfo:@{
            NSLocalizedDescriptionKey:        [NSString stringWithFormat:@"Web Socket connection was established, "
                                               "but Bayeux connection failed on host %@", self.baseURL.absoluteString],
            NSLocalizedFailureReasonErrorKey: message.error ?: @"Unknown",
         }];
        [self.delegateProxy clientDisconnected:self withMessage:message error:error];
    }
}

- (void)client:(FYClient *)client receivedDisconnectMessage:(FYMessage *)message {
    if ([message.successful boolValue]) {
        self.state = FYClientStateDisconnected;
        [self closeSocketConnection];
        [self.delegateProxy clientDisconnected:self withMessage:message error:nil];
    } else {
        self.state = FYClientStateDisconnecting;
        
        // Disconnection failed.
        NSError *error = [NSError errorWithDomain:FYErrorDomain code:FYErrorSubscribeFailed userInfo:@{
            NSLocalizedDescriptionKey:        [NSString stringWithFormat:@"Error on disconnecting from host %@",
                                               self.baseURL.absoluteString],
            NSLocalizedFailureReasonErrorKey: message.error ?: @"Unknown",
         }];
        [self.delegateProxy client:self failedWithError:error];
    }
}

- (void)client:(FYClient *)client receivedSubscribeMessage:(FYMessage *)message {
    if ([message.successful boolValue]) {
        [self.delegateProxy client:self subscriptionSucceedToChannel:message.subscription];
    } else {
        // Subscription failed.
        NSError *error = [NSError errorWithDomain:FYErrorDomain code:FYErrorSubscribeFailed userInfo:@{
            NSLocalizedDescriptionKey:        [NSString stringWithFormat:@"Error subscribing to channel '%@'", message.subscription],
            NSLocalizedFailureReasonErrorKey: message.error ?: @"Unknown",
         }];
        [self.delegateProxy client:self failedWithError:error];
    }
}

- (void)client:(FYClient *)client receivedUnsubscribeMessage:(FYMessage *)message {
    if ([message.successful boolValue]) {
        [self.channels removeObjectForKey:message.subscription];
    } else {
        // Unsubscription failed.
        NSError *error = [NSError errorWithDomain:FYErrorDomain code:FYErrorUnsubscribeFailed userInfo:@{
            NSLocalizedDescriptionKey:        [NSString stringWithFormat:@"Error unsubscribing from channel '%@'", message.subscription],
            NSLocalizedFailureReasonErrorKey: message.error ?: @"Unknown",
         }];
        [self.delegateProxy client:self failedWithError:error];
    }
}


#pragma mark - JSON serialization & deserialization

- (NSString *)stringBySerializingObject:(NSObject *)object {
    return [[NSString alloc] initWithData:[self dataBySerializingObject:object] encoding:NSUTF8StringEncoding];
}

- (NSData *)dataBySerializingObject:(NSObject *)object {
    NSError *error = nil;
    NSJSONWritingOptions options = 0;
    #ifdef FYDebug
        options |= NSJSONWritingPrettyPrinted;
    #endif
    NSData* data = [NSJSONSerialization dataWithJSONObject:object options:options error:&error];
    if (error) {
        // Object data was malformed.
        NSError *fyError = [NSError errorWithDomain:FYErrorDomain code:FYErrorMalformedObjectData userInfo:@{
             NSLocalizedDescriptionKey: @"Can't serialize malformed data.",
             NSUnderlyingErrorKey:      error,
         }];
        [self.delegateProxy client:self failedWithError:fyError];
        return nil;
    }
    return data;
}

- (id)deserializeString:(NSString *)string {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self deserializeData:data];
}

- (id)deserializeData:(NSData *)data {
    NSError *error = nil;
    id result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        // JSON string was malformed.
        NSError *fyError = [NSError errorWithDomain:FYErrorDomain code:FYErrorMalformedJSONData userInfo:@{
             NSLocalizedDescriptionKey: @"JSON data is malformed.",
             NSUnderlyingErrorKey:      error,
         }];
        [self.delegateProxy client:self failedWithError:fyError];
        return nil;
    } else {
        return result;
    }
}


#pragma mark - Generic helper

- (void)performBlock:(void(^)(FYClient *))block afterDelay:(NSTimeInterval)delay {
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC);
    __weak FYClient* this = self;
    dispatch_after(popTime, self.workerQueue, ^{
        block(this);
     });
}

- (void)chainActorForMetaChannel:(NSString *)channel onceWithActorBlock:(FYActorBlock)block {
    self.metaChannelActors[channel] = [FYBlockActor chain:self.metaChannelActors[channel]
                                                     once:block
                                                  restore:^(id<FYActor> actor) {
                                                      self.metaChannelActors[channel] = actor;
                                                  }];
}

@end
