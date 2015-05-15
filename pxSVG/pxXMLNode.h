//
//  pxXMLNode.h
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface pxXMLNode : NSObject
+ (NSArray*) parseTree:(NSData*)data;
@property (readonly) NSString *tagName;
@property (readonly) NSDictionary *attributes;
@property (readonly) NSArray *childNodes;
@end
