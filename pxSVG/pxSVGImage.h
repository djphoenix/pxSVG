//
//  pxSVGImage.h
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface pxSVGImage : NSObject
+ (instancetype) svgImageWithXML:(NSData*)data;
- (instancetype) initWithXML:(NSData*)data;
@property (nonatomic,readonly) CGRect bounds;
- (CALayer*)makeLayer;
@end
