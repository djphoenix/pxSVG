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
        __block NSURLResponse *resp;
        __block NSError *err;
        NSData *data;
        data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadRevalidatingCacheData timeoutInterval:30] returningResponse:&resp error:&err];
        if ([op isCancelled]) {
            op = nil, data = nil, resp = nil, err = nil;
            return;
        }
        __block NSString *str = data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:nil;
        data = nil;
        __block NSBlockOperation *sync = [NSBlockOperation blockOperationWithBlock:^{ @autoreleasepool {
            sync = nil;
            if ([op isCancelled] || !weakself) {
                op = nil, resp = nil, err = nil, str = nil;
                return;
            }
            weakself.loadOperation = op = nil;
            if (!err && [resp isKindOfClass:[NSHTTPURLResponse class]] && (((NSHTTPURLResponse*)resp).statusCode != 200))
                err = [NSError errorWithDomain:@"pxSVGLoader.httpStatus" code:((NSHTTPURLResponse*)resp).statusCode userInfo:nil];
            if (!err && !str)
                err = [NSError errorWithDomain:@"pxSVGLoader.emptyData" code:0 userInfo:nil];
            if (err) {
                resp = nil, str = nil;
                [weakself loadError:err];
                err = nil;
                return;
            }
            [weakself loadString:str];
            resp = nil, err = nil, str = nil;
        } }];
        [[NSOperationQueue mainQueue] addOperations:@[sync] waitUntilFinished:YES];
    } }];
    op.name = url.absoluteString;
    op.threadPriority = 0.1f;
    [[self.class loadQueue] addOperation:self.loadOperation=op];
}

- (void)loadData:(NSData *)data
{
    [self loadString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
}

- (void)loadString:(NSString *)string
{
    [self clean];
    __weak pxSVGLayer *weakself = self;
    __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{ @autoreleasepool {
        __block pxSVGImage *img = [pxSVGImage svgImageWithXML:string];
        if ([op isCancelled]) {
            op = nil, img = nil;
            return;
        }
        __block NSBlockOperation *sync = [NSBlockOperation blockOperationWithBlock:^{ @autoreleasepool {
            sync = nil;
            if ([op isCancelled] || !weakself) {
                op = nil, img = nil;
                return;
            }
            weakself.parseOperation = op = nil;
            if (!img) {
                img = nil;
                return [weakself loadError:[NSError errorWithDomain:@"pxSVGParser.parseError" code:0 userInfo:nil]];
            }
            [weakself loadImage:img];
            img = nil;
        } }];
        [[NSOperationQueue mainQueue] addOperations:@[sync] waitUntilFinished:YES];
    } }];
    op.threadPriority = 0.1f;
    [[self.class parseQueue] addOperation:self.parseOperation=op];
}

- (void)loadImage:(pxSVGImage*)image
{
    [self clean];
    CGRect bounds = image.bounds;
    __weak pxSVGLayer *weakself = self;
    __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{ @autoreleasepool {
        __block CALayer *img = [image makeLayer];
        if ([op isCancelled]) {
            op = nil, img = nil;
            return;
        }
        __block NSBlockOperation *sync = [NSBlockOperation blockOperationWithBlock:^{ @autoreleasepool {
            sync = nil;
            if ([op isCancelled] || !weakself) {
                img = nil, op = nil;
                return;
            }
            weakself.layerOperation = op = nil;
            [weakself clean];
            [weakself addSublayer:img];
            img = nil;
            weakself.contentRect = bounds;
            if ([weakself.svgDelegate respondsToSelector:@selector(svgLayerDidLoadImage:)])
                [weakself.svgDelegate svgLayerDidLoadImage:weakself];
        } }];
        [[NSOperationQueue mainQueue] addOperations:@[sync] waitUntilFinished:YES];
    } }];
    op.threadPriority = 0.2f;
    [[self.class layererQueue] addOperation:self.layerOperation=op];
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
        if (self.loadOperation) [self.loadOperation cancel];
        if (self.parseOperation) [self.parseOperation cancel];
        if (self.layerOperation) [self.layerOperation cancel];
        while (self.sublayers.count) [self.sublayers.firstObject removeFromSuperlayer];
        self.contentRect = CGRectZero;
    }
}

@end
