//
//  pxSVGLayer.m
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxSVGLayer.h"
#import "pxSVGImage.h"

@interface pxSVGLayer ()
@property NSOperation *loadOperation;
@property NSOperation *parseOperation;
@property NSOperation *layerOperation;
@property CGRect contentRect;
@end

@implementation pxSVGLayer

+ (NSOperationQueue*)loadQueue
{
    static NSOperationQueue *lq;
    if (!lq) {
        lq = [NSOperationQueue new];
        lq.name = @"pxSVG Load queue";
        [lq setMaxConcurrentOperationCount:10];
    }
    return lq;
}

+ (NSOperationQueue*)parseQueue
{
    static NSOperationQueue *pq;
    if (!pq) {
        pq = [NSOperationQueue new];
        pq.name = @"pxSVG Parser queue";
        [pq setMaxConcurrentOperationCount:10];
    }
    return pq;
}

+ (NSOperationQueue*)layererQueue
{
    static NSOperationQueue *pq;
    if (!pq) {
        pq = [NSOperationQueue new];
        pq.name = @"pxSVG Layer generator queue";
        [pq setMaxConcurrentOperationCount:10];
    }
    return pq;
}

- (void)dealloc
{
    if (self.loadOperation) [self.loadOperation cancel];
    if (self.parseOperation) [self.parseOperation cancel];
    if (self.layerOperation) [self.layerOperation cancel];
    self.layerOperation = self.parseOperation = self.loadOperation = nil;
}

- (void)loadURL:(NSURL *)url
{
    [self clean];
    __weak pxSVGLayer *weakself = self;
    __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{ @autoreleasepool {
        NSURLResponse *resp;
        NSError *err;
        NSData *data;
        data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadRevalidatingCacheData timeoutInterval:30] returningResponse:&resp error:&err];
        if (!err && [resp isKindOfClass:[NSHTTPURLResponse class]] && (((NSHTTPURLResponse*)resp).statusCode != 200))
            err = [NSError errorWithDomain:@"pxSVGLoader.httpStatus" code:((NSHTTPURLResponse*)resp).statusCode userInfo:nil];
        if (!err && !data)
            err = [NSError errorWithDomain:@"pxSVGLoader.emptyData" code:0 userInfo:nil];
        resp = nil;
        if ([op isCancelled]) {
            op = nil, data = nil, err = nil;
            return;
        }
        op = nil;
        if (err) {
            data = nil;
            [weakself performSelectorOnMainThread:@selector(loadError:) withObject:err waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
            err = nil;
            return;
        }
        [weakself performSelectorOnMainThread:@selector(loadData:) withObject:data waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
        data = nil, err = nil;
    } }];
    op.name = url.absoluteString;
    op.threadPriority = 0.1f;
    [[self.class loadQueue] addOperation:self.loadOperation=op];
}

- (void)loadData:(NSData *)data
{
    [self clean];
    __weak pxSVGLayer *weakself = self;
    __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{ @autoreleasepool {
        pxSVGImage *img = [pxSVGImage svgImageWithXML:data];
        if ([op isCancelled]) {
            op = nil, img = nil;
            return;
        }
        op = nil;
        if (!img) {
            img = nil;
            [weakself performSelectorOnMainThread:@selector(loadError:) withObject:[NSError errorWithDomain:@"pxSVGParser.parseError" code:0 userInfo:nil] waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
            return;
        }
        [weakself performSelectorOnMainThread:@selector(loadImage:) withObject:img waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
        img = nil;
    } }];
    op.threadPriority = 0.1f;
    [[self.class parseQueue] addOperation:self.parseOperation=op];
}

- (void)loadString:(NSString *)string
{
    [self loadData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)loadImage:(pxSVGImage*)image
{
    [self clean];
    CGRect bounds = image.bounds;
    __weak pxSVGLayer *weakself = self;
    __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{ @autoreleasepool {
        CALayer *img = [image makeLayer];
        img.bounds = bounds;
        if ([op isCancelled]) {
            op = nil, img = nil;
            return;
        }
        op = nil;
        [weakself performSelectorOnMainThread:@selector(loadLayer:) withObject:img waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
        img = nil;
    } }];
    op.threadPriority = 0.2f;
    [[self.class layererQueue] addOperation:self.layerOperation=op];
}

- (void)loadLayer:(CALayer*)layer
{
    [self clean];
    self.contentRect = layer.bounds;
    layer.bounds = (CGRect){CGPointZero,layer.frame.size};
    [self addSublayer:layer];
    if ([self.svgDelegate respondsToSelector:@selector(svgLayerDidLoadImage:)])
        [self.svgDelegate svgLayerDidLoadImage:self];
}

- (void)loadError:(NSError *)error
{
    [self clean];
    if ([self.svgDelegate respondsToSelector:@selector(svgLayer:didFailedLoad:)])
        [self.svgDelegate svgLayer:self didFailedLoad:error];
}

- (void)clean
{
    @autoreleasepool {
        if (self.loadOperation) {[self.loadOperation cancel];self.loadOperation = nil;}
        if (self.parseOperation) {[self.parseOperation cancel];self.parseOperation = nil;}
        if (self.layerOperation) {[self.layerOperation cancel];self.layerOperation = nil;}
        for (CALayer *l in [self.sublayers copy]) [l removeFromSuperlayer];
        self.contentRect = CGRectZero;
    }
}

@end
