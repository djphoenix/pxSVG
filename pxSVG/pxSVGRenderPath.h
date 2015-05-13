//
//  pxSVGRenderPath.h
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "pxXMLNode.h"

@interface pxSVGRenderPath : NSObject
+ (instancetype) pathWithXML:(pxXMLNode*)xmlNode;
- (instancetype) initWithXML:(pxXMLNode*)xmlNode;
@property (readonly) CGRect bounds;
- (CALayer*)makeLayer;
@end
