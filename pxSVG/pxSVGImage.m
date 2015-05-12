//
//  pxSVGImage.m
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxSVGImage.h"
#import "pxXMLNode.h"

@interface pxSVGImage ()
@property pxXMLNode *xmlTree;
@end

@implementation pxSVGImage
+ (instancetype)svgImageWithXML:(NSString *)xml
{
    return [[self alloc] initWithXML:xml];
}
- (instancetype)initWithXML:(NSString *)xml
{
    self = [self init];
    NSScanner *scan = [[NSScanner alloc] initWithString:xml];
    self.xmlTree = [[pxXMLNode parseTree:scan] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"tagName=%@",@"svg"]].firstObject;
    if (!self.xmlTree) return nil;
    
    return self;
}
@end
