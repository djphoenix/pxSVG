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
@property NSArray *colors;
@property NSArray *locations;
@property CGPoint startPoint, endPoint;
@end

@implementation pxSVGGradient
@end

@interface pxSVGPattern : pxSVGGroup
@property CATransform3D patternTransform;
@property CGRect patternBounds;
@end

@implementation pxSVGPattern
@end

@interface pxSVGRenderPath ()
@property NSMutableDictionary *defCache;
@property pxXMLNode *xml;
@property pxSVGObject *root;
@property CGRect bounds;
@end

@interface pxSVGPatternLayer : CALayer
@property (nonatomic) CALayer *patternLayer;
@property (nonatomic) CATransform3D patternTransform;
@end

@implementation pxSVGPatternLayer

+ (instancetype)layer
{
    return [super layer];
}

- (instancetype)init
{
    self = [super init];
    [self setNeedsDisplayOnBoundsChange:YES];
    [self setNeedsDisplay];
    return self;
}

- (void)setPatternLayer:(CALayer *)patternLayer
{
    _patternLayer = patternLayer;
    [self setNeedsDisplay];
}

- (void)setPatternTransform:(CATransform3D)patternTransform
{
    _patternTransform = patternTransform;
    [self setNeedsDisplay];
}

- (void)setNeedsDisplay
{
    if ([NSThread isMainThread]) return [super setNeedsDisplay];
    __weak id weakself = self;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (weakself) [weakself setNeedsDisplay];
    }];
}

- (void)drawInContext:(CGContextRef)ctx
{
    CGRect r = CGContextGetClipBoundingBox(ctx);
    CGAffineTransform tr = CATransform3DGetAffineTransform(self.patternTransform);
    CGSize sz = self.patternLayer.frame.size;
    sz = CGSizeApplyAffineTransform(sz, tr);
    CGPoint off = CGPointApplyAffineTransform((CGPoint){0,0}, tr); tr.tx = 0; tr.ty = 0;
    off.x = fmod(off.x,sz.width);
    off.y = fmod(off.y,sz.height);
    while (off.y < r.size.height) {
        CGFloat x = off.x;
        while (x < r.size.width) {
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, x, off.y);
            CGContextConcatCTM(ctx, tr);
            CGContextTranslateCTM(ctx, self.patternLayer.frame.origin.x, self.patternLayer.frame.origin.y);
            [self.patternLayer renderInContext:ctx];
            CGContextRestoreGState(ctx);
            x += sz.width;
        }
        off.y += sz.height;
    }
}

@end

@implementation pxSVGRenderPath
+ (instancetype)pathWithXML:(pxXMLNode *)xmlNode
{
    return [[self alloc] initWithXML:xmlNode];
}
- (instancetype)initWithXML:(pxXMLNode *)xmlNode
{
    self = [super init];
    self.xml = xmlNode;
    self.defCache = [NSMutableDictionary new];
    self.root = [self parseObject:self.xml inheritAttributes:nil];
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
        self.bounds = self.root.bounds;
    }
    self.xml = nil;
    return self;
}
- (pxSVGObject*)findDef:(NSString*)name inNode:(pxXMLNode*)xml
{
    id def;
    for (pxXMLNode *n in xml.childNodes) {
        if ([[n.attributes objectForKey:@"id"] isEqualToString:name]) {
            def = [self parseObject:n inheritAttributes:nil];
            if (def) return def;
        }
        def = [self findDef:name inNode:n];
        if (def) {
            [self.defCache setObject:def forKey:name];
            return def;
        }
    }
    return nil;
}
- (pxSVGObject*)findDef:(NSString*)name
{
    if (!name) return nil;
    id def = [self.defCache objectForKey:name];
    if (def) return def;
    return [self findDef:name inNode:self.xml];
}
- (pxSVGObject*)reuseObjectWithAttributes:(NSDictionary*)attributes
{
    NSString *href = [attributes objectForKey:@"xlink:href"];
    if (!href) href = [attributes objectForKey:@"href"];
    if (!href) return nil;
    href = [href substringFromIndex:1];
    pxSVGObject *oobj = [self findDef:href], *obj;
    if (!oobj) return nil;
    obj = [oobj.class new];
    obj.strokeColor = oobj.strokeColor;
    obj.strokeWidth = oobj.strokeWidth;
    obj.opacity = oobj.opacity;
    obj.fillOpacity = oobj.fillOpacity;
    obj.fillColor = oobj.fillColor;
    obj.fillDef = oobj.fillDef;
    obj.clipDef = oobj.clipDef;
    if ([attributes objectForKey:@"fill"]) {
        CGFloat a = obj.fillOpacity;
        if ([[attributes objectForKey:@"fill"] hasPrefix:@"url("]) {
            NSString *u = [[attributes objectForKey:@"fill"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            u = [[u substringWithRange:NSMakeRange(3, u.length-4)] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r\t ()#"]];
            obj.fillDef = u;
        } else obj.fillColor = [pxSVGObject colorWithSVGColor:[attributes objectForKey:@"fill"]];
        if (obj.fillColor) [obj.fillColor getWhite:nil alpha:&a];
        obj.fillOpacity = [attributes objectForKey:@"fill-opacity"]?[[attributes objectForKey:@"fill-opacity"] doubleValue]:a;
    }
    if ([oobj respondsToSelector:@selector(d)])
        [(id)obj setD:[(id)oobj d]];
    if ([oobj respondsToSelector:@selector(subnodes)])
        [(id)obj setSubnodes:[(id)oobj subnodes]];
    CATransform3D tr = oobj.transform;
    if ([attributes objectForKey:@"x"]) tr = CATransform3DTranslate(tr, [[attributes objectForKey:@"x"] doubleValue], 0, 0);
    if ([attributes objectForKey:@"y"]) tr = CATransform3DTranslate(tr, 0, [[attributes objectForKey:@"y"] doubleValue], 0);
    if ([attributes objectForKey:@"width"]) {
        CGFloat ow = oobj.bounds.size.width, w = [[attributes objectForKey:@"width"] doubleValue];
        tr = CATransform3DScale(tr, ow/w, 1, 1);
    }
    if ([attributes objectForKey:@"height"]) {
        CGFloat oh = oobj.bounds.size.height, h = [[attributes objectForKey:@"height"] doubleValue];
        tr = CATransform3DScale(tr, 1, oh/h, 1);
    }
    if ([attributes objectForKey:@"transform"]) tr = CATransform3DConcat(tr, [pxSVGObject transformFromString:[attributes objectForKey:@"transform"]]);
    obj.transform = tr;
    obj.animations = oobj.animations;
    return obj;
}
- (pxSVGGradient*)parseLinearGradient:(pxXMLNode*)node
{
    NSString *gid = [node.attributes objectForKey:@"id"];
    if (!gid) return nil;
    NSString *href = [node.attributes objectForKey:@"xlink:href"];
    if (!href) href = [node.attributes objectForKey:@"href"];
    CGPoint sp = CGPointZero, ep = (CGPoint){INFINITY,INFINITY};
    NSMutableArray *cls, *locs;
    if (href) {
        href = [href substringFromIndex:1];
        pxSVGGradient *g = (id)[self findDef:href];
        if (![g isKindOfClass:[pxSVGGradient class]]) return nil;
        sp = g.startPoint;
        ep = g.endPoint;
        cls = (id)g.colors;
        locs = (id)g.locations;
    } else {
        cls = [NSMutableArray new], locs = [NSMutableArray new];
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
    }
    if ([node.attributes objectForKey:@"x1"]) sp.x = [[node.attributes objectForKey:@"x1"] doubleValue];
    if ([node.attributes objectForKey:@"y1"]) sp.y = [[node.attributes objectForKey:@"y1"] doubleValue];
    if ([node.attributes objectForKey:@"x2"]) ep.x = [[node.attributes objectForKey:@"x2"] doubleValue];
    if ([node.attributes objectForKey:@"y2"]) ep.y = [[node.attributes objectForKey:@"y2"] doubleValue];
    if (cls.count) {
        pxSVGGradient *g = [pxSVGGradient new];
        g.colors = cls;
        g.locations = locs;
        g.startPoint = sp;
        g.endPoint = ep;
        [self.defCache setObject:g forKey:gid];
        return g;
    }
    return nil;
}
- (pxSVGPattern*)parsePattern:(pxXMLNode*)node
{
    NSString *pid = [node.attributes objectForKey:@"id"];
    if (!pid) return nil;
    NSString *href = [node.attributes objectForKey:@"xlink:href"];
    if (!href) href = [node.attributes objectForKey:@"href"];
    pxSVGPattern *p = nil;
    if (href) {
        href = [href substringFromIndex:1];
        pxSVGPattern *op = (id)[self findDef:href];
        if (![op isKindOfClass:[pxSVGPattern class]]) return nil;
        p = [pxSVGPattern new];
        p.id = pid;
        p.opacity = op.opacity;
        p.fillOpacity = op.fillOpacity;
        p.fillColor = op.fillColor;
        p.fillDef = op.fillDef;
        p.clipDef = op.clipDef;
        p.strokeColor = op.strokeColor;
        p.strokeWidth = op.strokeWidth;
        p.subnodes = op.subnodes;
        p.transform = op.transform;
        p.patternTransform = op.patternTransform;
        p.patternBounds = op.patternBounds;
    } else {
        p = [pxSVGPattern new];
        p.id = pid;
        p.opacity = NAN;
        p.fillOpacity = NAN;
        [p loadAttributes:node.attributes];
        NSMutableArray *sub = [NSMutableArray new];
        for (pxXMLNode *n in node.childNodes) {
            pxSVGObject *o = [self parseObject:n inheritAttributes:p];
            if (o) [sub addObject:o];
        }
        p.subnodes = [NSArray arrayWithArray:sub];
        p.transform = CATransform3DIdentity;
        p.patternTransform = CATransform3DIdentity;
        p.patternBounds = CGRectNull;
    }
    if ([node.attributes objectForKey:@"viewBox"]) {
        NSArray *vb = [[node.attributes objectForKey:@"viewBox"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        p.patternBounds = (CGRect){
            {
                [vb[0] doubleValue],
                [vb[1] doubleValue]
            },{
                [vb[2] doubleValue],
                [vb[3] doubleValue]
            }
        };
    } else if ([node.attributes objectForKey:@"width"] &&
               [node.attributes objectForKey:@"height"]) {
        CGPoint o = CGPointZero;
        if ([node.attributes objectForKey:@"x"] &&
            [node.attributes objectForKey:@"y"]) {
            o = (CGPoint){
                [[node.attributes objectForKey:@"x"] doubleValue],
                [[node.attributes objectForKey:@"y"] doubleValue]
            };
        }
        p.patternBounds = (CGRect){
            o,{
                [[node.attributes objectForKey:@"width"] doubleValue],
                [[node.attributes objectForKey:@"height"] doubleValue]
            }
        };
    } else if (CGRectIsNull(p.patternBounds)) {
        p.patternBounds = p.bounds;
    }
    if ([node.attributes objectForKey:@"patternTransform"]) {
        p.patternTransform = CATransform3DConcat(p.patternTransform, [pxSVGObject transformFromString:[node.attributes objectForKey:@"patternTransform"]]);
    }
    [self.defCache setObject:p forKey:pid];
    return p;
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
    if ([node.tagName isEqualToString:@"pattern"]) return [self parsePattern:node];;
    Class objClass = pxSVGObject.class;
    if ([node.tagName isEqualToString:@"g"])
        objClass = pxSVGGroup.class;
    else if ([node.tagName isEqualToString:@"svg"])
        objClass = pxSVGGroup.class;
    else if ([node.tagName isEqualToString:@"clipPath"])
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
    if (obj.id) [self.defCache setObject:obj forKey:obj.id];
    if (obj.fillDef) [self findDef:obj.fillDef];
    if (obj.clipDef) [self findDef:obj.clipDef];
    if (node.childNodes.count) {
        NSMutableArray *subnodes = [NSMutableArray new];
        for (pxXMLNode *n in node.childNodes) {
            pxSVGObject *o = [self parseObject:n inheritAttributes:obj];
            if (o && ![n.tagName isEqualToString:@"defs"] && ![n.tagName isEqualToString:@"clipPath"]) {
                [subnodes addObject:o];
            }
        }
        [obj setSubnodes:[NSArray arrayWithArray:subnodes]];
    }
    return obj;
}
- (UIBezierPath*)mergePath:(pxSVGObject*)node
{
    UIBezierPath *bp = [UIBezierPath new];
    if ([node respondsToSelector:@selector(d)]) {
        [bp appendPath:[(id)node d]];
    }
    if ([node respondsToSelector:@selector(subnodes)]) {
        for (pxSVGObject *o in [(id)node subnodes]) {
            [bp appendPath:[self mergePath:o]];
        }
    }
    return bp;
}
- (CALayer *)makeLayerWithNode:(pxSVGObject*)node rootBounds:(CGRect)bounds;
{
    CALayer *l;
    if ([node respondsToSelector:@selector(d)]) {
        CAShapeLayer *sl = [CAShapeLayer layer];
        UIBezierPath *p = [(id)node d];
        sl.path = p.CGPath;
        if (node.fillDef) {
            sl.fillColor = [UIColor clearColor].CGColor;
            id def = [self findDef:node.fillDef];
            if ([def isKindOfClass:[pxSVGGradient class]]) {
                CAGradientLayer *gl = [CAGradientLayer layer];
                gl.frame = p.bounds;
                gl.startPoint = (CGPoint){([def startPoint].x-gl.frame.origin.x)/gl.frame.size.width,([def startPoint].y-gl.frame.origin.y)/gl.frame.size.height};
                gl.endPoint = (CGPoint){([def endPoint].x-gl.frame.origin.x)/gl.frame.size.width,([def endPoint].y-gl.frame.origin.y)/gl.frame.size.height};
                gl.locations = [def locations];
                gl.colors = [def colors];
                gl.opacity = isnan(node.fillOpacity)?1:node.fillOpacity;
                CAShapeLayer *ml = [CAShapeLayer layer];
                ml.frame = (CGRect){{-p.bounds.origin.x,-p.bounds.origin.y},{ceil(p.bounds.size.width+p.bounds.origin.x),ceil(p.bounds.size.height+p.bounds.origin.y)}};
                ml.path = sl.path;
                gl.mask = ml;
                [sl addSublayer:gl];
            }
            if ([def isKindOfClass:[pxSVGPattern class]]) {
                pxSVGPatternLayer *tl = [pxSVGPatternLayer layer];
                CALayer *pl = [self makeLayerWithNode:def rootBounds:[def patternBounds]];
                tl.patternLayer = pl;
                tl.patternTransform = CATransform3DTranslate([def patternTransform],p.bounds.origin.x,p.bounds.origin.y,0);
                tl.frame = p.bounds;
                tl.opacity = isnan(node.fillOpacity)?1:node.fillOpacity;
                CAShapeLayer *ml = [CAShapeLayer layer];
                ml.frame = (CGRect){{-p.bounds.origin.x,-p.bounds.origin.y},{ceil(p.bounds.size.width+p.bounds.origin.x),ceil(p.bounds.size.height+p.bounds.origin.y)}};
                ml.path = sl.path;
                tl.mask = ml;
                [sl addSublayer:tl];
            }
        } else
            sl.fillColor = [(node.fillColor?:[UIColor blackColor]) colorWithAlphaComponent:isnan(node.fillOpacity)?1:node.fillOpacity].CGColor;
        sl.strokeColor = node.strokeColor.CGColor;
        sl.lineWidth = isnan(node.strokeWidth)?0:node.strokeWidth;
        l = sl;
    } else {
        l = [CALayer layer];
    }
    if (node.clipDef) {
        id def = [self findDef:node.clipDef];
        if ([def isKindOfClass:[pxSVGObject class]]) {
            UIBezierPath *bp = [self mergePath:def];
            CAShapeLayer *ml = [CAShapeLayer layer];
            ml.frame = (CGRect){CGPointZero,{ceil(bp.bounds.size.width),ceil(bp.bounds.size.height)}};
            ml.path = bp.CGPath;
            l.mask = ml;
        }
    }
    l.frame = (CGRect){{-bounds.origin.x,-bounds.origin.y},bounds.size};
    CATransform3D tr = node.transform;
    tr = CATransform3DConcat(CATransform3DMakeTranslation( bounds.size.width/2,  bounds.size.height/2, 0), tr);
    tr = CATransform3DConcat(tr, CATransform3DMakeTranslation(-bounds.size.width/2, -bounds.size.height/2, 0));
    l.transform = tr;
    bounds.origin = CGPointZero;
    l.opacity = node.opacity;
    if ([node respondsToSelector:@selector(subnodes)]) {
        for (pxSVGObject *n in [(id)node subnodes]) {
            CALayer *sl = [self makeLayerWithNode:n rootBounds:bounds];
            if (sl) [l addSublayer:sl];
        }
    }
    return l;
}
- (CALayer *)makeLayer
{
    return [self makeLayerWithNode:self.root rootBounds:self.bounds];
}
@end
