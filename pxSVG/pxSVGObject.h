//
//  pxSVGObject.h
//  pxSVG
//
//  Created by Yury Popov on 12.05.15.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface pxSVGObject : NSObject
+ (CATransform3D) transformFromString:(NSString*)string;
+ (UIColor*) colorWithSVGColor:(NSString*)string;
- (void) loadAttributes:(NSDictionary*)attributes;
- (void) setSubnodes:(NSArray*)subnodes;
@property NSString *id;
@property NSArray *animations;
@property UIColor *fillColor;
@property UIColor *strokeColor;
@property CGFloat strokeWidth;
@property CGFloat opacity;
@property CATransform3D transform;
@end
