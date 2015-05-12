//
//  pxSVGView.h
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import <UIKit/UIKit.h>

@class pxSVGView;

@protocol pxSVGViewDelegate <NSObject>
- (void) svgViewDidLoadImage:(pxSVGView*)svgView;
- (void) svgView:(pxSVGView*)svgLayer didFailedLoad:(NSError*)error;
@end

@interface pxSVGView : UIView
@property (weak) id<pxSVGViewDelegate> svgDelegate;
- (void) loadData:(NSData*)data;
- (void) loadString:(NSString*)string;
- (void) loadURL:(NSURL*)url;
@end
