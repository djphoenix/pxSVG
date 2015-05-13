//
//  pxSVGView.m
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxSVGView.h"
#import "pxSVGLayer.h"

@interface pxSVGView () <pxSVGLayerDelegate>
@property (weak) pxSVGLayer *svgLayer;
@end

@implementation pxSVGView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.contentMode = UIViewContentModeScaleAspectFit;
    pxSVGLayer *sl = [pxSVGLayer new];
    [self.layer addSublayer:sl];
    self.svgLayer=sl;
    self.svgLayer.svgDelegate = self;
    return self;
}

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
    if (layer != self.layer) return;
    self.svgLayer.transform = CATransform3DIdentity;
    [self.svgLayer setFrame:self.layer.bounds];
    CATransform3D tr = CATransform3DIdentity;
    CGRect c = self.svgLayer.contentRect;
    CGFloat
    scx = c.size.width/self.bounds.size.width,
    scy = c.size.height/self.bounds.size.height,
    sc;
    switch (self.contentMode) {
        case UIViewContentModeScaleAspectFit:
            sc = MAX(scx,scy);
            tr = CATransform3DMakeScale(1/sc, 1/sc, 1);
            tr = CATransform3DTranslate(tr, -c.size.width/2, -c.size.height/2, 0);
            tr = CATransform3DTranslate(tr, self.bounds.size.width/2, self.bounds.size.height/2, 0);
            break;
        default: break;
    }
    [self.svgLayer setTransform:tr];
}

- (void)svgLayerDidLoadImage:(pxSVGLayer *)svgLayer
{
    [self setNeedsLayout];
    [self layoutSublayersOfLayer:self.layer];
    [self setNeedsDisplay];
    if ([self.svgDelegate respondsToSelector:@selector(svgViewDidLoadImage:)])
        [self.svgDelegate svgViewDidLoadImage:self];
}

- (void)svgLayer:(pxSVGLayer *)svgLayer didFailedLoad:(NSError *)error
{
    if ([self.svgDelegate respondsToSelector:@selector(svgView:didFailedLoad:)])
        [self.svgDelegate svgView:self didFailedLoad:error];
}

- (void)loadData:(NSData *)data
{
    [self.svgLayer loadData:data];
}

- (void)loadString:(NSString *)string
{
    [self.svgLayer loadString:string];
}

- (void)loadURL:(NSURL *)url
{
    [self.svgLayer loadURL:url];
}

@end
