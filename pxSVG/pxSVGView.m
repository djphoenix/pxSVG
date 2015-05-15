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
@end

@implementation pxSVGView

+ (Class)layerClass
{
    return [pxSVGLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.contentMode = UIViewContentModeScaleAspectFit;
    pxSVGLayer *sl = (pxSVGLayer*)self.layer;
    sl.svgDelegate = self;
    return self;
}

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
    [super layoutSublayersOfLayer:layer];
    if (layer != self.layer) return;
    self.layer.transform = CATransform3DIdentity;
    [self.layer setFrame:self.bounds];
    CATransform3D tr = CATransform3DIdentity;
    CGRect c = ((pxSVGLayer*)self.layer).contentRect;
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
    [(pxSVGLayer*)self.layer setTransform:tr];
}

- (void)svgLayerDidLoadImage:(pxSVGLayer *)svgLayer
{
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
    [(pxSVGLayer*)self.layer loadData:data];
}

- (void)loadString:(NSString *)string
{
    [(pxSVGLayer*)self.layer loadString:string];
}

- (void)loadURL:(NSURL *)url
{
    [(pxSVGLayer*)self.layer loadURL:url];
}

@end
