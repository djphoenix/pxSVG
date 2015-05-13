//
//  pxSVGGroup.m
//  pxSVG
//
//  Created by Yury Popov on 12.05.15.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxSVGGroup.h"

@implementation pxSVGGroup
- (CGRect)bounds
{
    CGRect f = CGRectNull;
    for (pxSVGObject *o in [self subnodes]) {
        f = CGRectUnion(f, o.bounds);
    }
    if (CGRectIsNull(f)) return f;
    return CGRectApplyAffineTransform(f, CATransform3DGetAffineTransform(self.transform));
}

@end
