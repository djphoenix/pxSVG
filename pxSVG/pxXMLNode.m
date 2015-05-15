//
//  pxXMLNode.m
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxXMLNode.h"

@interface pxXMLNode ()
@property NSString *tagName;
@property NSDictionary *attributes;
@property NSArray *childNodes;
@end

@implementation pxXMLNode

+ (NSArray *)parseTree:(NSData *)data
{
    static NSCharacterSet *seps; if (!seps) seps = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSMutableDictionary *attrs = [[NSMutableDictionary alloc] initWithCapacity:100];
    NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:100];
    NSMutableArray *nodeStack = [[NSMutableArray alloc] initWithCapacity:100];
    NSString *tagName, *attrName, *attrValue;
    pxXMLNode *node;
    NSUInteger idx = 0, tidx;
    const char* bytes = data.bytes;
    NSRange tagRange, attrRange;
    while (idx < data.length) {
        while ((idx < data.length) && (bytes[idx] != '<')) idx++;
        tagRange.location = idx;
        while ((idx < data.length) && (bytes[idx] != '>')) idx++;
        tagRange.length = idx-tagRange.location;
        idx++;
        if (tagRange.length < 2) break;
        if (bytes[tagRange.location+1] == '/') {
            if (nodeStack.count == 0) break;
            nodes = nodeStack.lastObject;
            [nodeStack removeLastObject];
            continue;
        }
        if (bytes[tagRange.location+1] == '?') continue;
        if (bytes[tagRange.location+1] == '!') continue;
        {
            tidx = 1;
            attrRange.location = 1;
            [attrs removeAllObjects];
            while ((tidx < tagRange.length) && ![seps characterIsMember:bytes[tagRange.location+tidx]]) tidx++;
            attrRange.length = tidx-attrRange.location;
            tagName = [[NSString alloc] initWithBytes:&bytes[tagRange.location+attrRange.location] length:attrRange.length encoding:NSUTF8StringEncoding];
            while ((tidx < tagRange.length) && [seps characterIsMember:bytes[tagRange.location+tidx]]) tidx++;
            while (tidx < tagRange.length) {
                attrRange.location = tidx;
                while ((tidx < tagRange.length) && (bytes[tagRange.location+tidx] != '=') && (bytes[tagRange.location+tidx] != '/')) tidx++;
                attrRange.length = tidx-attrRange.location;
                if (attrRange.length == 0) break;
                attrName = [[NSString alloc] initWithBytes:&bytes[tagRange.location+attrRange.location] length:attrRange.length encoding:NSUTF8StringEncoding];
                if (tagRange.length-idx < 2) break;
                if ((bytes[tagRange.location+tidx] != '=') || (bytes[tagRange.location+tidx+1] != '"')) break;
                tidx += 2;
                attrRange.location = tidx;
                while ((tidx < tagRange.length) && (bytes[tagRange.location+tidx] != '"')) tidx++;
                attrRange.length = tidx-attrRange.location;
                attrValue = [[NSString alloc] initWithBytes:&bytes[tagRange.location+attrRange.location] length:attrRange.length encoding:NSUTF8StringEncoding];
                tidx++;
                while ((tidx < tagRange.length) && [seps characterIsMember:bytes[tagRange.location+tidx]]) tidx++;
                [attrs setObject:attrValue?:@"" forKey:attrName];
            }
            BOOL selfClose = bytes[tagRange.location+tagRange.length-1] == '/';
            node = [self new];
            node.tagName = tagName;
            node.attributes = [NSDictionary dictionaryWithDictionary:attrs];
            [nodes addObject:node];
            if (selfClose) node.childNodes = @[];
            else {
                [nodeStack addObject:nodes];
                node.childNodes = nodes = [[NSMutableArray alloc] initWithCapacity:100];
            }
        }
    }
    return (nodeStack.count>0)?nodeStack.firstObject:[NSArray arrayWithArray:nodes];
}

- (NSString *)description
{
    NSMutableString *str = [NSMutableString new];
    [str appendFormat:@"<%@",self.tagName];
    for (NSString *k in self.attributes) {
        [str appendFormat:@" %@=\"%@\"",k,self.attributes[k]];
    }
    if (self.childNodes.count == 0) {
        [str appendString:@"/>"];
    } else {
        [str appendString:@">\n"];
        for (pxXMLNode *n in self.childNodes) {
            [str appendFormat:@" %@\n",[n.description stringByReplacingOccurrencesOfString:@"\n" withString:@"\n "]];
        }
        [str appendFormat:@"</%@>",self.tagName];
    }
    return [NSString stringWithString:str];
}

@end
