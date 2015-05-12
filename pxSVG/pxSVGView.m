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
    pxSVGLayer *sl = [pxSVGLayer new];
    [self.layer addSublayer:sl];
    self.svgLayer=sl;
    self.svgLayer.svgDelegate = self;
    return self;
}

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
    if (layer != self.layer) return;
    [self.svgLayer setFrame:self.layer.bounds];
}

- (void)svgLayerDidLoadImage:(pxSVGLayer *)svgLayer
{
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
