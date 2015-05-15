//
//  pxSVGImage.m
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxSVGImage.h"
#import "pxXMLNode.h"
#import "pxSVGRenderPath.h"

@interface pxSVGImage ()
@property pxSVGRenderPath *renderPath;
@end

@implementation pxSVGImage
+ (instancetype)svgImageWithXML:(NSData *)xml
{
    return [[self alloc] initWithXML:xml];
}
- (instancetype)initWithXML:(NSData *)xml
{
    pxXMLNode *xmlTree =
    [[pxXMLNode parseTree:xml]
     filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"tagName=%@",@"svg"]]
    .firstObject;
    if (!xmlTree) return nil;
    pxSVGRenderPath *renderPath = [pxSVGRenderPath pathWithXML:xmlTree];
    if (!renderPath) return nil;
    self = [self init];
    self.renderPath = renderPath;
    return self;
}

- (CGRect)bounds
{
    return self.renderPath.bounds;
}
- (CALayer *)makeLayer
{
    return [self.renderPath makeLayer];
}
@end
