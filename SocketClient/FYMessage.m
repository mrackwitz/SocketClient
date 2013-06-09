//
//  FYMessage.m
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

#import "FYMessage.h"


/**
 Internal category for 'FYMessage' to parse RFC3339 strings into 'NSDate'.
 */
@interface NSDate (Helper)

/**
 Get a 'NSDate' instance by parsing a RFC3339 string by 'NSDateFormatter'.
 
 @param  dateString  a RFC3339 string
 */
+ (NSDate *)dateWithRFC3339String:(NSString *)dateString;

@end


@implementation NSDate (Helper)

+ (NSDate *)dateWithRFC3339String:(NSString *)dateString {
	static NSDateFormatter *formatter;
    if (!formatter) {
        formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssz";
    }
    return [formatter dateFromString:dateString];
}

@end



@implementation FYMessage

static NSSet* FYMessageKeySet;

+ (void)load {
    FYMessageKeySet = [NSSet setWithArray:@[
        @"channel",
        @"version",
        @"minimumVersion",
        @"supportedConnectionTypes",
        @"clientId",
        @"advice",
        @"data",
        @"successful",
        @"subscription",
        @"error",
        @"ext",
     ]];
}

- (id)initWithUserInfo:(NSDictionary *)userInfo {
    self = [super init];
    if (self) {
        self.fayeId = userInfo[@"id"];
        
        // Parse timestamp, if needed
        id timestamp = userInfo[@"timestamp"];
        if (timestamp) {
            if ([timestamp isKindOfClass:NSDate.class]) {
                self.timestamp = timestamp;
            } else if ([timestamp isKindOfClass:NSString.class]) {
                self.timestamp = [NSDate dateWithRFC3339String:timestamp];
            } else {
                NSAssert(@"Timestamp '%@' is from unexpected class %@. Expected NSDate or NSString.",
                         timestamp, [timestamp class]);
            }
        }
        
        // Filter keys
        NSMutableDictionary *filteredUserInfo = userInfo.mutableCopy;
        for (NSString* key in userInfo) {
            if (![FYMessageKeySet containsObject:key]) {
                [filteredUserInfo removeObjectForKey:key];
            }
        }
        
        [self setValuesForKeysWithDictionary:filteredUserInfo];
    }
    return self;
}

- (NSString *)description {
    NSMutableString* description = super.description.mutableCopy;
    [description appendString:@"{\n"];
    for (NSString* key in FYMessageKeySet) {
        [description appendFormat:@"\t%@ : %@\n", key, [self valueForKey:key] ?: @"<null>"];
    }
    [description appendString:@"}"];
    return description;
}

@end
