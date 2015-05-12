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

+ (NSArray *)parseTree:(NSScanner *)scanner
{
    NSMutableArray *nodes = [NSMutableArray new];
    NSString *tag;
    pxXMLNode *node;
    while (!scanner.isAtEnd) {
        [scanner scanUpToString:@"<" intoString:nil];
        [scanner scanUpToString:@">" intoString:&tag];
        tag = [tag stringByAppendingString:@">"]; [scanner scanString:@">" intoString:nil];
        if ([tag hasPrefix:@"</"]) break;
        if ([tag characterAtIndex:1] == '?') continue;
        if ([tag characterAtIndex:1] == '!') continue;
        node = [self parseNode:tag childScanner:scanner];
        [nodes addObject:node];
    }
    return [NSArray arrayWithArray:nodes];
}

+ (instancetype)parseNode:(NSString *)string childScanner:(NSScanner *)childScanner
{
    NSCharacterSet *seps = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSScanner *scan = [[NSScanner alloc] initWithString:string];
    [scan scanString:@"<" intoString:nil];
    NSString *tagName, *attrName, *attrValue;
    NSMutableDictionary *attrs = [NSMutableDictionary new];
    [scan scanUpToCharactersFromSet:seps intoString:&tagName]; [scan scanCharactersFromSet:seps intoString:nil];
    
    while ([scan scanUpToString:@"=" intoString:&attrName]) {
        if(![scan scanString:@"=\"" intoString:nil]) break;
        [scan scanUpToString:@"\"" intoString:&attrValue];
        [scan scanString:@"\"" intoString:nil];
        [scan scanCharactersFromSet:seps intoString:nil];
        [attrs setObject:attrValue?:@"" forKey:attrName];
    }
    if ([tagName hasSuffix:@">"]) tagName = [tagName substringToIndex:tagName.length-1];
    BOOL selfClose = [[attrName stringByTrimmingCharactersInSet:seps] hasPrefix:@"/"];
    pxXMLNode *node = [self new];
    node.tagName = tagName;
    node.attributes = attrs;
    node.childNodes = selfClose?@[]:[self parseTree:childScanner];
    return node;
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
