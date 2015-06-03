//
//  SocketClient_Private.h
//  SocketClient
//
//  Created by Marius Rackwitz on 15.05.13.
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

/**
 Needed for compatiblity to versions below iOS 6.1, where ARC doesn't support automatic dispatch_retain
 & dispatch_release.
 
 Adapted from SRWebSocket.h
 */
#if OS_OBJECT_USE_OBJC_RETAIN_RELEASE
    #define fy_dispatch_retain(x)
    #define fy_dispatch_release(x)
    #define fy_maybe_bridge(x) ((__bridge void *) x)
#else
    #define fy_dispatch_retain(x) dispatch_retain(x)
    #define fy_dispatch_release(x) dispatch_release(x)
    #define fy_maybe_bridge(x) (x)
#endif


/**
 Logging macro
 */
//#define FYDebug 1

#ifdef FYDebug
    #define FYLog(...) NSLog(__VA_ARGS__)
#else
    #define FYLog(...) 
#endif
