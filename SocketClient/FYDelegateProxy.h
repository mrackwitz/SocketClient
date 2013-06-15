//
//  FYDelegateProxy.h
//  SocketClient
//
//  Created by Marius Rackwitz on 15.06.13.
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


/**
 Define a concrete FYDelegateProxy subclass.
 
 The subclass will be named: DelegateProtocol##Proxy.
 
 The subclass implements the given protocol and forces it's proxiedObject to do the same. You will profit from using
 this macro with compile-time type safety and no warnings because of unimplemented, but required methods.
 
 This macro is only to use in implementation files.
 */
#define FYDefineDelegateProxy(DelegateProtocol) \
    FYInterfaceDelegateProxy(DelegateProtocol)\
    FYImplementDelegateProxy(DelegateProtocol) \

#define FYInterfaceDelegateProxy(DelegateProtocol) \
    @interface DelegateProtocol##Proxy : FYDelegateProxy <DelegateProtocol> \
    @property (nonatomic, weak) id<NSObject,DelegateProtocol> proxiedObject; \
    @end \

#define FYImplementDelegateProxy(DelegateProtocol) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wprotocol\"") \
    _Pragma("clang diagnostic ignored \"-Wincomplete-implementation\"") \
    @implementation DelegateProtocol##Proxy \
    @end \
    _Pragma("clang diagnostic pop")


/**
 An instance of FYDelegateProxy is used internally in FYClient to dispatch calls to its [delegate]([FYClient delegate]).
 
 A `NSProxy` subclass `FYDelegateProxy` is used in `FYClient` as property [delegateProxy]([FYClient delegateProxy]) to
 dispatch calls to the delegate property. This is used to don't have to think about non-implemented optional protocol
 methods. All declared selectors could be invoked and are forwared to the real delegate implementation stored in
 `proxiedObject` property of `FYDelegateProxy`. So the getter and setter implementation of the property `delegate` of
 `FYClient` have to return / mutate ```self.clientDelegateProxy.proxiedObject```.
 
 So instead of writing a lot of repeative code like:
 
    if ([self.delegate respondsToSelector:@selector(client:didFoo:)]) {
        [self.delegate client:self didFoo:foo];
    }
 
 You can simply write your code like:
 
    [self.clientDelegateProxy client:self didFoo:foo];
 
 This won't raise any "selector not found" exception, if this selector is optional and not implemented.
 */
@interface FYDelegateProxy : NSProxy

/**
 Factory method for main queue delegate proxy.
 */
+ (instancetype)new;

/**
 Dispatch queue on which delegate calls are executed.
 */
@property (nonatomic) dispatch_queue_t delegateQueue;

/**
 The proxied object.
 */
@property (nonatomic, weak) id<NSObject> proxiedObject;

@end
