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

@interface pxSVGGradient : NSObject
@property CGGradientRef gradient;
@property NSArray *colors;
@property NSArray *locations;
@property CGPoint startPoint, endPoint;
@end

@implementation pxSVGGradient
@end

@interface pxSVGRenderPath ()
@property NSMutableDictionary *defs;
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
    self.defs = [NSMutableDictionary new];
    self.root = [self parseObject:xmlNode inheritAttributes:nil];
    if ([xmlNode.attributes objectForKey:@"viewBox"]) {
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
    } else if ([xmlNode.attributes objectForKey:@"width"] &&
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
- (pxSVGObject*)reuseObjectWithAttributes:(NSDictionary*)attributes
{
    NSString *href = [attributes objectForKey:@"xlink:href"];
    if (!href) href = [attributes objectForKey:@"href"];
    if (!href) return nil;
    href = [href substringFromIndex:1];
    pxSVGObject *oobj = [self.defs objectForKey:href], *obj;
    if (!oobj) return nil;
    obj = [oobj.class new];
    obj.fillColor = oobj.fillColor;
    obj.fillDef = oobj.fillDef;
    obj.strokeColor = oobj.strokeColor;
    obj.strokeWidth = oobj.strokeWidth;
    obj.opacity = oobj.opacity;
    obj.fillOpacity = oobj.fillOpacity;
    if ([oobj respondsToSelector:@selector(d)])
        [(id)obj setD:[(id)oobj d]];
    if ([oobj respondsToSelector:@selector(subnodes)])
        [(id)obj setSubnodes:[(id)oobj subnodes]];
    CATransform3D tr = oobj.transform;
    if ([attributes objectForKey:@"x"]) tr = CATransform3DTranslate(tr, [[attributes objectForKey:@"x"] doubleValue], 0, 0);
    if ([attributes objectForKey:@"y"]) tr = CATransform3DTranslate(tr, 0, [[attributes objectForKey:@"y"] doubleValue], 0);
    if ([attributes objectForKey:@"width"]) {
        CGFloat ow = [self objBounds:oobj].size.width, w = [[attributes objectForKey:@"width"] doubleValue];
        tr = CATransform3DScale(tr, ow/w, 1, 1);
    }
    if ([attributes objectForKey:@"height"]) {
        CGFloat oh = [self objBounds:oobj].size.width, h = [[attributes objectForKey:@"height"] doubleValue];
        tr = CATransform3DScale(tr, 1, oh/h, 1);
    }
    if ([attributes objectForKey:@"transform"]) tr = CATransform3DConcat(tr, [pxSVGObject transformFromString:[attributes objectForKey:@"transform"]]);
    obj.transform = tr;
    obj.animations = oobj.animations;
    return obj;
}
- (void)parseLinearGradient:(pxXMLNode*)node
{
    NSString *gid = [node.attributes objectForKey:@"id"];
    if (!gid) return;
    NSString *href = [node.attributes objectForKey:@"xlink:href"];
    if (!href) href = [node.attributes objectForKey:@"href"];
    CGGradientRef gr;
    CGPoint sp = CGPointZero, ep = (CGPoint){INFINITY,INFINITY};
    NSMutableArray *cls, *locs;
    if (href) {
        href = [href substringFromIndex:1];
        pxSVGGradient *g = [self.defs objectForKey:href];
        if (![g isKindOfClass:[pxSVGGradient class]]) return;
        gr = g.gradient;
        sp = g.startPoint;
        ep = g.endPoint;
        cls = (id)g.colors;
        locs = (id)g.locations;
    } else {
        cls = [NSMutableArray new], locs = [NSMutableArray new];
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        for (pxXMLNode *s in node.childNodes) {
            if (![s.tagName isEqualToString:@"stop"]) {
                NSLog(@"Unknown gradient node: %@",s);
            }
            NSMutableDictionary *ma = [s.attributes mutableCopy];
            if ([s.attributes objectForKey:@"style"]) {
                for (NSString *ss in [[s.attributes objectForKey:@"style"] componentsSeparatedByString:@";"]) {
                    NSUInteger sep = [ss rangeOfString:@":"].location;
                    if (sep == NSNotFound) continue;
                    NSString *k = [[ss substringToIndex:sep] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    NSString *v = [[ss substringFromIndex:sep+1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    [ma setObject:v forKey:k];
                }
            }
            if ([ma objectForKey:@"stop-color"] && [ma objectForKey:@"offset"]) {
                UIColor *cl = [pxSVGObject colorWithSVGColor:[ma objectForKey:@"stop-color"]];
                if ([ma objectForKey:@"stop-opacity"])
                    cl = [cl colorWithAlphaComponent:[[ma objectForKey:@"stop-opacity"] doubleValue]];
                [cls addObject:(__bridge id)cl.CGColor];
                [locs addObject:@([[ma objectForKey:@"offset"] doubleValue])];
            }
        }
        CGFloat *locs_a = CFAllocatorAllocate(CFAllocatorGetDefault(), (sizeof(CGFloat)*locs.count), 0);
        for (NSUInteger i=0; i<locs.count; i++) {
            locs_a[i] = [locs[i] doubleValue];
        }
        gr = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)cls, locs_a);
        CFAllocatorDeallocate(CFAllocatorGetDefault(), locs_a);
        CGColorSpaceRelease(cs);
    }
    if ([node.attributes objectForKey:@"x1"]) sp.x = [[node.attributes objectForKey:@"x1"] doubleValue];
    if ([node.attributes objectForKey:@"y1"]) sp.y = [[node.attributes objectForKey:@"y1"] doubleValue];
    if ([node.attributes objectForKey:@"x2"]) ep.x = [[node.attributes objectForKey:@"x2"] doubleValue];
    if ([node.attributes objectForKey:@"y2"]) ep.y = [[node.attributes objectForKey:@"y2"] doubleValue];
    if (gr) {
        pxSVGGradient *g = [pxSVGGradient new];
        g.gradient = gr;
        g.colors = cls;
        g.locations = locs;
        g.startPoint = sp;
        g.endPoint = ep;
        [self.defs setObject:g forKey:gid];
    }
}
- (pxSVGObject*)parseObject:(pxXMLNode*)node inheritAttributes:(pxSVGObject*)inherit
{
    if ([node.tagName rangeOfString:@":"].location != NSNotFound) return nil;
    if ([node.tagName isEqualToString:@"metadata"]) return nil;
    if ([node.tagName isEqualToString:@"marker"]) return nil;
    if ([node.tagName isEqualToString:@"filter"]) return nil;
    if ([node.tagName isEqualToString:@"a"]) return nil;
    if ([node.tagName isEqualToString:@"use"]) return [self reuseObjectWithAttributes:node.attributes];
    if ([node.tagName isEqualToString:@"linearGradient"]) {
        [self parseLinearGradient:node];
        return nil;
    }
    Class objClass = pxSVGObject.class;
    if ([node.tagName isEqualToString:@"g"])
        objClass = pxSVGGroup.class;
    else if ([node.tagName isEqualToString:@"svg"])
        objClass = pxSVGGroup.class;
    else if ([node.tagName isEqualToString:@"defs"])
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
        obj.fillColor = inherit?inherit.fillColor:[UIColor blackColor];
    if (isnan(obj.strokeWidth))
        obj.strokeWidth = inherit?inherit.strokeWidth:0;
    if (isnan(obj.fillOpacity))
        obj.fillOpacity = inherit?inherit.fillOpacity:1;
    if (!obj.strokeColor)
        obj.strokeColor = inherit?inherit.strokeColor:nil;
    if (obj.id) [self.defs setObject:obj forKey:obj.id];
    if (node.childNodes.count) {
        NSMutableArray *subnodes = [NSMutableArray new];
        for (pxXMLNode *n in node.childNodes) {
            pxSVGObject *o = [self parseObject:n inheritAttributes:obj];
            if (o && ![n.tagName isEqualToString:@"defs"]) {
                [subnodes addObject:o];
            }
        }
        [obj setSubnodes:[NSArray arrayWithArray:subnodes]];
    }
    return obj;
}
- (CALayer *)makeLayerWithNode:(pxSVGObject*)node
{
    CALayer *l, *fl;
    if ([node respondsToSelector:@selector(d)]) {
        CAShapeLayer *sl = [CAShapeLayer new];
        sl.path = [(id)node d].CGPath;
        if (node.fillDef) {
            sl.fillColor = [UIColor clearColor].CGColor;
            id def = [self.defs objectForKey:node.fillDef];
            if ([def isKindOfClass:[pxSVGGradient class]]) {
                CAGradientLayer *gl = [CAGradientLayer new];
                gl.frame = [(id)node d].bounds;
                gl.startPoint = (CGPoint){([def startPoint].x-gl.frame.origin.x)/gl.frame.size.width,([def startPoint].y-gl.frame.origin.y)/gl.frame.size.height};
                gl.endPoint = (CGPoint){([def endPoint].x-gl.frame.origin.x)/gl.frame.size.width,([def endPoint].y-gl.frame.origin.y)/gl.frame.size.height};
                gl.locations = [def locations];
                gl.colors = [def colors];
                gl.opacity = isnan(node.fillOpacity)?1:node.fillOpacity;
                CAShapeLayer *ml = [CAShapeLayer new];
                ml.frame = (CGRect){{0,0},{gl.frame.size.width+gl.frame.origin.x,gl.frame.size.height+gl.frame.origin.y}};
                ml.path = sl.path;
                gl.mask = ml;
                [sl addSublayer:gl];
                fl = gl;
            }
        } else
            sl.fillColor = [(node.fillColor?:[UIColor blackColor]) colorWithAlphaComponent:isnan(node.fillOpacity)?1:node.fillOpacity].CGColor;
        sl.strokeColor = node.strokeColor.CGColor;
        sl.lineWidth = isnan(node.strokeWidth)?0:node.strokeWidth;
        l = sl;
    } else {
        l = [CALayer new];
    }
    l.frame = self.bounds;
    CATransform3D tr = node.transform;
    tr = CATransform3DConcat(CATransform3DMakeTranslation( self.bounds.size.width/2,  self.bounds.size.height/2, 0), tr);
    tr = CATransform3DConcat(tr, CATransform3DMakeTranslation(-self.bounds.size.width/2, -self.bounds.size.height/2, 0));
    l.transform = tr;
    l.opacity = node.opacity;
    if ([node respondsToSelector:@selector(subnodes)]) {
        for (pxSVGObject *n in [(id)node subnodes]) {
            CALayer *sl = [self makeLayerWithNode:n];
            if (sl) [l addSublayer:sl];
        }
    }
    return l;
}
- (CALayer *)makeLayer
{
    return [self makeLayerWithNode:self.root];
}
@end
