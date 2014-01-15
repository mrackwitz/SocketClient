//
//  NSURL+FYHelper.h
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
 Internal category for 'FYClient' to replace host name with arguments from `hosts` advice, to fulfill this advice on
 connection problems. Furthermore it is used to replace 'ws' scheme by 'http', if handshake is done asynchronically
 over a separate NSURLConnection.
 */
@interface NSURL (FYHelper)

/**
 Replaces the host in an URL with another host.
 
 @param scheme  The scheme of the new URL conforming to RFC 1808.
 
 @param host    The host of the new URL conforming to RFC 1808.
 */
- (NSURL *)URLWithScheme:(NSString *)scheme host:(NSString *)host __attribute((nonnull));

@end
