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

- (void)dealloc
{
    if (self.loadOperation) [self.loadOperation cancel];
    if (self.parseOperation) [self.parseOperation cancel];
}

- (void)loadURL:(NSURL *)url
{
    [self clean];
    __weak pxSVGLayer *weakself = self;
    __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        NSURLResponse *resp;
        NSError *err;
        NSData *data;
        data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadRevalidatingCacheData timeoutInterval:30] returningResponse:&resp error:&err];
        if ([op isCancelled]) return;
        NSString *str = data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:nil;
        NSBlockOperation *sync = [NSBlockOperation blockOperationWithBlock:^{
            if ([op isCancelled]) return;
            if (!weakself) return;
            weakself.loadOperation = nil;
            op = nil;
            NSError *error = err;
            if (!error && [resp isKindOfClass:[NSHTTPURLResponse class]] && (((NSHTTPURLResponse*)resp).statusCode != 200))
                error = [NSError errorWithDomain:@"pxSVGLoader.httpStatus" code:((NSHTTPURLResponse*)resp).statusCode userInfo:nil];
            if (!error && !str)
                error = [NSError errorWithDomain:@"pxSVGLoader.emptyData" code:0 userInfo:nil];
            if (error) return [weakself loadError:error];
            [weakself loadString:str];
        }];
        [[NSOperationQueue mainQueue] addOperations:@[sync] waitUntilFinished:YES];
    }];
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
    __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        pxSVGImage *img = [pxSVGImage svgImageWithXML:string];
        if ([op isCancelled]) return;
        NSBlockOperation *sync = [NSBlockOperation blockOperationWithBlock:^{
            if ([op isCancelled]) return;
            if (!weakself) return;
            weakself.parseOperation = nil;
            op = nil;
            if (!img) return [weakself loadError:[NSError errorWithDomain:@"pxSVGParser.parseError" code:0 userInfo:nil]];
            [weakself loadImage:img];
        }];
        [[NSOperationQueue mainQueue] addOperations:@[sync] waitUntilFinished:YES];
    }];
    op.threadPriority = 0.1f;
    [[self.class parseQueue] addOperation:self.parseOperation=op];
}

- (void)loadImage:(pxSVGImage*)image
{
    [self clean];
    __weak pxSVGLayer *weakself = self;
    __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        CALayer *img = [image makeLayer];
        if ([op isCancelled]) return;
        NSBlockOperation *sync = [NSBlockOperation blockOperationWithBlock:^{
            if ([op isCancelled]) return;
            if (!weakself) return;
            [weakself addSublayer:img];
            weakself.parseOperation = nil;
            op = nil;
            weakself.contentRect = image.bounds;
            if ([weakself.svgDelegate respondsToSelector:@selector(svgLayerDidLoadImage:)])
                [weakself.svgDelegate svgLayerDidLoadImage:weakself];
        }];
        [[NSOperationQueue mainQueue] addOperations:@[sync] waitUntilFinished:YES];
    }];
    op.threadPriority = 0.1f;
    [[self.class parseQueue] addOperation:self.parseOperation=op];
}

- (void)loadError:(NSError *)error
{
    if ([self.svgDelegate respondsToSelector:@selector(svgLayer:didFailedLoad:)])
        [self.svgDelegate svgLayer:self didFailedLoad:error];
}

- (void)clean
{
    if (self.loadOperation) [self.loadOperation cancel];
    if (self.parseOperation) [self.parseOperation cancel];
    while (self.sublayers.count) [self.sublayers.firstObject removeFromSuperlayer];
    self.contentRect = CGRectZero;
}

@end
