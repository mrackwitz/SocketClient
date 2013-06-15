//
//  FYDelegateProxy.m
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

#import "FYDelegateProxy.h"
#import "SocketClient_Private.h"


@implementation FYDelegateProxy

+ (instancetype)new {
    FYDelegateProxy *proxy = [self alloc];
    proxy.delegateQueue = dispatch_get_main_queue();
    return proxy;
}

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
    // Because there seems a delay when dispatching invocations asynchronically by using GCD, the arguments need to be
    // retained manually so that they don't get released before the invocation was forwarded. This would cause otherwise
    // an EXC_BAD_ACCESS(code=2). This could also occur if you are debugging with breakpoints...
    [invocation retainArguments];
    
    FYLog(@"[%@] %@", self.class, NSStringFromSelector(invocation.selector));
    
    if ([_proxiedObject respondsToSelector:invocation.selector]) {
        dispatch_async(_delegateQueue, ^{
            [invocation invokeWithTarget:self.proxiedObject];
         });
    }
}

- (void)setDelegateQueue:(dispatch_queue_t)delegateQueue {
    if (delegateQueue) {
        fy_dispatch_retain(delegateQueue);
    }
    if (_delegateQueue) {
        fy_dispatch_release(_delegateQueue);
    }
    _delegateQueue = delegateQueue;
}

@end
