//
//  FYMessage.h
//  SocketClient
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
//  [51] http://svn.cometd.com/trunk/bayeux/bayeux.html#toc_51
//  [61] http://svn.cometd.com/trunk/bayeux/bayeux.html#toc_61
//  [62] http://svn.cometd.com/trunk/bayeux/bayeux.html#toc_62
*/

#import <Foundation/Foundation.h>


/**
 Represents the Bayeux message structure
 */
@interface FYMessage : NSObject

/**
 Specify the source or destination of the message.
 
 The channel message field MUST be included in every Bayeux message to specify the source or destination of the message.
 In a request, the channel specifies the destination of the message, and in a response it specifies the source of the
 message.
 */
@property (nonatomic, retain) NSString *channel;

/**
 Indicate the protocol version expected by the client/server.
 
 Included in messages to/from the "/meta/handshake" channel.
 */
@property (nonatomic, retain) NSString *version;

/**
 Indicate the oldest protocol version that can be handled by the client/server.
 
 Included in messages to/from the "/meta/handshake" channel.
 */
@property (nonatomic, retain) NSString *minimumVersion;

/**
 Included in messages to/from the "/meta/handshake" channel to allow clients and servers to reveal the transports that
 are supported.
 
 The value is an array of strings, with each string representing a transport name. Defined connection types include:
 
 - long-polling
   This transport is defined in [section 6.1](61).
 - callback-polling
   This transport is defined in [section 6.2](62).
 - iframe
   OPTIONAL transport using the document content of a hidden iframe element.
 - flash
   OPTIONAL transport using the capabilities of a browser flash plugin.
 */
@property (nonatomic, retain) NSArray *supportedConnectionTypes;

/**
 Uniquely identifies a client to the Bayeux server.
 
 The clientId message field MUST be included in every message sent to the server except for messages sent to the
 "/meta/handshake" channel and MAY be omitted in a publish message (see [section 5.1 of the Bayeux protocol](51)).
 
 The clientId field MUST be returned in every message response except for a failed handshake request and for a publish
 message response that was send without clientId.
 */
@property (nonatomic, retain) NSString *clientId;

/**
 Provides a way for servers to inform clients of their preferred mode of client operation so that in conjunction with
 server-enforced limits, Bayeux implementations can prevent resource exhaustion and inelegant failure modes.
 
 The advice field is a object containing general and transport specific values that indicate modes of operation,
 timeouts and other potential transport specific parameters. Fields may occur either in the top level of a
 message or within a transport specific section.
 
 Unless otherwise specified in sections 5 and 6, any Bayeux response message may contain an advice field. Advice
 received always superceeds any previous received advice.
 */
@property (nonatomic, retain) NSDictionary *advice;

/**
 Replaces "id" in Bayeux protocol.
 
 An id field MAY be included in any Bayeux message with an alpha numeric value.
 
 Generation of IDs is implementation specific and may be provided by the application. Messages published to
 ```/meta/⁠⁠**``` and ```/service/⁠**``` SHOULD have id fields that are unique within the the connection.
 
 Messages sent in response to messages delivered to ```/meta/⁠**``` channels MUST use the same message id as the
 request message.
 
 Messages sent in response to messages delivered to ```/service/⁠**``` channels SHOULD use the same message id as
 the request message or an id derived from the request message id.
 */
// Used \U+2060 to silent warning "'/*' within block comment" on '/⁠⁠**' by Xcode.
@property (nonatomic, retain) NSString *fayeId;

/**
 Sent time of the message.
 
 Is OPTIONAL in all Bayeux messages.
 */
@property (nonatomic, retain) NSDate *timestamp;

/**
 An object that contains event information.
 
 MUST be included in publish messages, and a Bayeux server MUST include the data field in an event
 delivery message.
 */
@property (nonatomic, retain) NSDictionary *data;

/**
 Used to indicate success or failure.
 
 MUST be included in responses to the "/meta/handshake", "/meta/connect", "/meta/subscribe","/meta/unsubscribe",
 "/meta/disconnect", and publish channels.
 */
@property (nonatomic, retain) NSNumber *successful;

/**
 Specifies the channels the client wishes to subscribe to or unsubscribe from.
 
 The subscription message field MUST be included in requests and responses to/from the "/meta/subscribe" or
 "/meta/unsubscribe" channels.
 */
@property (nonatomic, retain) NSString *subscription;

/**
 Indicate the type of error that occurred when a request returns with a false successful message.
 
 The error message field should be sent as a string in the following format:
 
    error            = error_code ":" error_args ":" error_message
                       | error_code ":" ":" error_message
    error_code       = digit digit digit
    error_args       = string *( "," string )
    error_message    = string
 */
@property (nonatomic, retain) NSString *error;

/**
 SHOULD be an object with top level names distinguished by implementation names (eg. "org.dojo.Bayeux.field").
 
 An ext field MAY be included in any Bayeux message.
 The contents of ext may be arbitrary values that allow extensions to be negotiated and implemented between server and
 client implementations.
 */
@property (nonatomic, retain) NSObject *ext;

/**
 Initializer
 
 @param userInfo  contains unserialized JSON message
 */
- (id)initWithUserInfo:(NSDictionary *)userInfo;

@end
