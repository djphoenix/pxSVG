//
//  pxSVGRenderPath.m
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxSVGRenderPath.h"
#import "pxSVGGroup.h"
#import "pxSVGPath.h"

@interface pxSVGRenderPath ()
@property NSDictionary *defs;
@property pxSVGObject *root;
@property CGRect bounds;
@end

@implementation pxSVGRenderPath
+ (instancetype)pathWithXML:(pxXMLNode *)xmlNode
{
    return [[self alloc] initWithXML:xmlNode];
}
- (instancetype)initWithXML:(pxXMLNode *)xmlNode
{
    self = [super init];
    self.root = [self parseObject:xmlNode inheritAttributes:nil];
    if ([xmlNode.attributes objectForKey:@"width"] &&
        [xmlNode.attributes objectForKey:@"height"]) {
        CGPoint o = CGPointZero;
        if ([xmlNode.attributes objectForKey:@"x"] &&
            [xmlNode.attributes objectForKey:@"y"]) {
            o = (CGPoint){
                [[xmlNode.attributes objectForKey:@"x"] doubleValue],
                [[xmlNode.attributes objectForKey:@"y"] doubleValue]
            };
        }
        self.bounds = (CGRect){
            o,{
                [[xmlNode.attributes objectForKey:@"width"] doubleValue],
                [[xmlNode.attributes objectForKey:@"height"] doubleValue]
            }
        };
    } else if ([xmlNode.attributes objectForKey:@"viewBox"]) {
        NSArray *vb = [[xmlNode.attributes objectForKey:@"viewBox"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        self.bounds = (CGRect){
            {
                [vb[0] doubleValue],
                [vb[1] doubleValue]
            },{
                [vb[2] doubleValue],
                [vb[3] doubleValue]
            }
        };
    } else {
        self.bounds = [self objBounds:self.root];
    }
    return self;
}
- (CGRect) objBounds:(pxSVGObject*)obj
{
    if ([obj respondsToSelector:@selector(d)]) {
        UIBezierPath *path = [(id)obj d];
        if (path) return CGRectApplyAffineTransform(path.bounds, CATransform3DGetAffineTransform(obj.transform));
    }
    if ([obj respondsToSelector:@selector(subnodes)]) {
        CGRect f = CGRectNull;
        for (pxSVGObject *o in [(id)obj subnodes]) {
            f = CGRectUnion(f, [self objBounds:o]);
        }
        return CGRectApplyAffineTransform(f, CATransform3DGetAffineTransform(obj.transform));
    }
    return CGRectNull;
}
- (pxSVGObject*)parseObject:(pxXMLNode*)node inheritAttributes:(pxSVGObject*)inherit
{
    if ([node.tagName rangeOfString:@":"].location != NSNotFound) return nil;
    if ([node.tagName isEqualToString:@"metadata"]) return nil;
    Class objClass = pxSVGObject.class;
    if ([node.tagName isEqualToString:@"g"])
        objClass = pxSVGGroup.class;
    else if ([node.tagName isEqualToString:@"svg"])
        objClass = pxSVGGroup.class;
    else if ([node.tagName isEqualToString:@"path"])
        objClass = pxSVGPath.class;
    else if ([node.tagName isEqualToString:@"polygon"])
        objClass = pxSVGPath.class;
    else if ([node.tagName isEqualToString:@"ellipse"])
        objClass = pxSVGPath.class;
    else if ([node.tagName isEqualToString:@"circle"])
        objClass = pxSVGPath.class;
    else if ([node.tagName isEqualToString:@"rect"])
        objClass = pxSVGPath.class;
    else NSLog(@"Unknown tag: %@",node.tagName);
    pxSVGObject *obj = [objClass new];
    [obj loadAttributes:node.attributes];
    if (!obj.fillColor)
        obj.fillColor = inherit.fillColor;
    if (obj.strokeWidth == NAN)
        obj.strokeWidth = inherit.strokeWidth;
    if (!obj.strokeColor)
        obj.strokeColor = inherit.strokeColor;
    if (node.childNodes.count) {
        NSMutableArray *subnodes = [NSMutableArray new];
        for (pxXMLNode *n in node.childNodes) {
            pxSVGObject *o = [self parseObject:n inheritAttributes:obj];
            if (o) {
                [subnodes addObject:o];
            }
        }
        [obj setSubnodes:[NSArray arrayWithArray:subnodes]];
    }
    return obj;
}
- (CALayer *)makeLayerWithNode:(pxSVGObject*)node withOffset:(CGPoint)off
{
    CGRect f = [self objBounds:node];
    if (CGRectIsNull(f)) return nil;
    CALayer *l;
    if ([node respondsToSelector:@selector(d)]) {
        CAShapeLayer *sl = [CAShapeLayer new];
        CGAffineTransform t = CGAffineTransformMakeTranslation(-f.origin.x, -f.origin.y);
        CGPathRef p = CGPathCreateCopyByTransformingPath([(id)node d].CGPath, &t);
        sl.path = p;
        CGPathRelease(p);
        sl.fillColor = (node.fillColor?:[UIColor blackColor]).CGColor;
        sl.strokeColor = node.strokeColor.CGColor;
        sl.lineWidth = node.strokeWidth==NAN?0:node.strokeWidth;
        l = sl;
    } else {
        l = [CALayer new];
    }
    l.frame = CGRectOffset(f, -off.x, -off.y);
    l.transform = node.transform;
    l.opacity = node.opacity;
    if ([node respondsToSelector:@selector(subnodes)]) {
        for (pxSVGObject *n in [(id)node subnodes]) {
            CALayer *sl = [self makeLayerWithNode:n withOffset:(CGPoint){f.origin.x+off.x,f.origin.y+off.y}];
            if (sl) [l addSublayer:sl];
        }
    }
    return l;
}
- (CALayer *)makeLayer
{
    return [self makeLayerWithNode:self.root withOffset:CGPointZero];
}
@end
