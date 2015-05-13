//
//  pxSVGLayer.h
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import <UIKit/UIKit.h>

@class pxSVGLayer;

@protocol pxSVGLayerDelegate <NSObject>
- (void) svgLayerDidLoadImage:(pxSVGLayer*)svgLayer;
- (void) svgLayer:(pxSVGLayer*)svgLayer didFailedLoad:(NSError*)error;
@end

@interface pxSVGLayer : CALayer
@property (weak) id<pxSVGLayerDelegate> svgDelegate;
- (void) loadData:(NSData*)data;
- (void) loadString:(NSString*)string;
- (void) loadURL:(NSURL*)url;
@property (nonatomic,readonly) CGRect contentRect;
@end
