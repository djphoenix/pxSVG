//
//  pxSVGPath.m
//  pxSVG
//
//  Created by Yury Popov on 12.05.15.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxSVGPath.h"

@interface NSScanner (CGPoint)
- (CGPoint) scanCGPoint;
- (CGPoint) scanCGPointWithOffset:(CGPoint)off;
@end

@implementation NSScanner (CGPoint)
- (CGPoint) scanCGPoint
{
    double x,y;
    [self scanString:@"," intoString:nil];
    [self scanDouble:&x];
    [self scanString:@"," intoString:nil];
    [self scanDouble:&y];
    return (CGPoint){x,y};
}
- (CGPoint)scanCGPointWithOffset:(CGPoint)off
{
    CGPoint p = [self scanCGPoint];
    return (CGPoint){p.x+off.x,p.y+off.y};
}
@end

@implementation pxSVGPath

- (UIBezierPath*)bezierPathWithString:(NSString*)string
{
    static NSCharacterSet *cmds; if (!cmds) cmds = [NSCharacterSet characterSetWithCharactersInString:@"MmCcSsLlHhVvAaZz"];
    NSScanner *scanner = [NSScanner scannerWithString:string];
    [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *cmd; unichar lastCmd = 0;
    UIBezierPath *bp = [UIBezierPath new];
    CGPoint p = CGPointZero, c1, c2;
    double d, r, s;
    while (!scanner.atEnd) {
        if (cmd.length>1) cmd=[cmd substringFromIndex:1];
        else if (![scanner scanCharactersFromSet:cmds intoString:&cmd]) {
            if ([cmds characterIsMember:lastCmd]) {
                cmd = [NSString stringWithCharacters:&lastCmd length:1];
            } else {
                NSLog(@"Unknown character: %@",[string substringWithRange:(NSRange){scanner.scanLocation,1}]);
            }
            break;
        }
        lastCmd = [cmd characterAtIndex:0];
        switch ([cmd characterAtIndex:0]) {
            case 'M':
                [bp moveToPoint:p = [scanner scanCGPoint]];
                break;
            case 'm':
                [bp moveToPoint:p = [scanner scanCGPointWithOffset:p]];
                break;
            case 'C':
                c1 = [scanner scanCGPoint];
                c2 = [scanner scanCGPoint];
                [bp addCurveToPoint:p=[scanner scanCGPoint] controlPoint1:c1 controlPoint2:c2];
                break;
            case 'c':
                c1 = [scanner scanCGPointWithOffset:p];
                c2 = [scanner scanCGPointWithOffset:p];
                [bp addCurveToPoint:p = [scanner scanCGPointWithOffset:p] controlPoint1:c1 controlPoint2:c2];
                break;
            case 'S':
                c1 = (CGPoint){p.x*2.f-c2.x,p.y*2.f-c2.y};
                c2 = [scanner scanCGPoint];
                p = [scanner scanCGPoint];
                [bp addCurveToPoint:p controlPoint1:c1 controlPoint2:c2];
                break;
            case 's':
                c1 = (CGPoint){p.x*2.f-c2.x,p.y*2.f-c2.y};
                c2 = [scanner scanCGPointWithOffset:p];
                p = [scanner scanCGPointWithOffset:p];
                [bp addCurveToPoint:p controlPoint1:c1 controlPoint2:c2];
                break;
            case 'A':
                c2 = [scanner scanCGPoint]; // r
                [scanner scanString:@"," intoString:nil];
                [scanner scanDouble:&d]; d *= M_PI; d /= 180.f; // a
                [scanner scanString:@"," intoString:nil];
                [scanner scanDouble:nil];
                [scanner scanString:@"," intoString:nil];
                [scanner scanDouble:nil];
                c1 = p;
                p = [scanner scanCGPoint];
                c1 = (CGPoint){(c1.x+p.x)/2.f,(c1.y+p.y)/2.f};
                r = sqrt((c2.x-c1.x)*(c2.x-c1.x)+(c2.y-c1.y)*(c2.y-c1.y));
                s = atan2(p.x-c1.x, p.y-c1.y)+M_PI_2;
                [bp addArcWithCenter:c1 radius:r startAngle:s endAngle:s+d clockwise:d>0];
                break;
            case 'a':
                c2 = [scanner scanCGPointWithOffset:p]; // r
                [scanner scanString:@"," intoString:nil];
                [scanner scanDouble:&d]; d *= M_PI; d /= 180.f; // a
                [scanner scanString:@"," intoString:nil];
                [scanner scanDouble:nil];
                [scanner scanString:@"," intoString:nil];
                [scanner scanDouble:nil];
                c1 = p;
                p = [scanner scanCGPointWithOffset:p];
                c1 = (CGPoint){(c1.x+p.x)/2.f,(c1.y+p.y)/2.f};
                r = sqrt((c2.x-c1.x)*(c2.x-c1.x)+(c2.y-c1.y)*(c2.y-c1.y));
                s = atan2(p.x-c1.x, p.y-c1.y)+M_PI_2;
                [bp addArcWithCenter:c1 radius:r startAngle:s endAngle:s+d clockwise:d>0];
                break;
            case 'V':
                [scanner scanDouble:&d]; p.y = d;
                [bp addLineToPoint:p];
                break;
            case 'v':
                [scanner scanDouble:&d]; p.y+= d;
                [bp addLineToPoint:p];
                break;
            case 'H':
                [scanner scanDouble:&d]; p.x = d;
                [bp addLineToPoint:p];
                break;
            case 'h':
                [scanner scanDouble:&d]; p.x+= d;
                [bp addLineToPoint:p];
                break;
            case 'L':
                [bp addLineToPoint:p=[scanner scanCGPoint]];
                break;
            case 'l':
                [bp addLineToPoint:p=[scanner scanCGPointWithOffset:p]];
                break;
            case 'z':
            case 'Z':
                [bp closePath];
                break;
                
            default:
                NSLog(@"Unknown command: %@",cmd);
                return nil;
        }
    }
    return bp;
}

- (UIBezierPath*)bezierPolygonWithString:(NSString*)string
{
    static NSCharacterSet *cmds; if (!cmds) cmds = [NSCharacterSet characterSetWithCharactersInString:@"MmCcSsLlHhVvAaZz"];
    NSScanner *scanner = [NSScanner scannerWithString:string];
    [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    UIBezierPath *bp = [UIBezierPath new];
    [bp moveToPoint:[scanner scanCGPoint]];
    while (!scanner.atEnd) {
        [bp addLineToPoint:[scanner scanCGPoint]];
    }
    [bp closePath];
    return bp;
}

- (void)loadAttributes:(NSDictionary *)attributes
{
    [super loadAttributes:attributes];
    if ([attributes objectForKey:@"d"]) self.d = [self bezierPathWithString:[attributes objectForKey:@"d"]];
    else if ([attributes objectForKey:@"points"]) self.d = [self bezierPolygonWithString:[attributes objectForKey:@"points"]];
    else if ([attributes objectForKey:@"cx"] &&
             [attributes objectForKey:@"cy"] &&
             [attributes objectForKey:@"rx"] &&
             [attributes objectForKey:@"ry"]) {
        CGRect r;
        r.size.width = [[attributes objectForKey:@"rx"] doubleValue];
        r.size.height = [[attributes objectForKey:@"ry"] doubleValue];
        r.origin.x = [[attributes objectForKey:@"cx"] doubleValue] - r.size.width;
        r.origin.y = [[attributes objectForKey:@"cy"] doubleValue] - r.size.height;
        r.size.width *= 2; r.size.height *= 2;
        self.d = [UIBezierPath bezierPathWithOvalInRect:r];
    }
    else if ([attributes objectForKey:@"cx"] &&
             [attributes objectForKey:@"cy"] &&
             [attributes objectForKey:@"r"]) {
        CGRect r;
        r.size.width = [[attributes objectForKey:@"r"] doubleValue];
        r.size.height = [[attributes objectForKey:@"r"] doubleValue];
        r.origin.x = [[attributes objectForKey:@"cx"] doubleValue] - r.size.width;
        r.origin.y = [[attributes objectForKey:@"cy"] doubleValue] - r.size.height;
        r.size.width *= 2; r.size.height *= 2;
        self.d = [UIBezierPath bezierPathWithOvalInRect:r];
    }
    else if ([attributes objectForKey:@"width"] &&
             [attributes objectForKey:@"height"]) {
        CGRect r;
        r.size.width = [[attributes objectForKey:@"width"] doubleValue];
        r.size.height = [[attributes objectForKey:@"height"] doubleValue];
        r.origin.x = [[attributes objectForKey:@"x"] doubleValue];
        r.origin.y = [[attributes objectForKey:@"y"] doubleValue];
        self.d = [UIBezierPath bezierPathWithRect:r];
    } else NSLog(@"%@",attributes);
}
@end
