//
//  pxSVGImage.h
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface pxSVGImage : NSObject
+ (instancetype) svgImageWithXML:(NSString*)data;
- (instancetype) initWithXML:(NSString*)data;
@property (nonatomic,readonly) CGRect bounds;
@end
