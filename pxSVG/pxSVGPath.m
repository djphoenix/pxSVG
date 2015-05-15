//
//  pxSVGPath.m
//  pxSVG
//
//  Created by Yury Popov on 12.05.15.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxSVGPath.h"

@interface pxSVGScanner: NSObject
+ (instancetype) scannerWithString:(NSString*)string;
- (instancetype) initWithString:(NSString*)string;
- (unichar) scanCharacter:(unichar)character;
- (CGFloat) scanFloat;
- (unichar) scanCommand;
- (BOOL) scanFlag;
- (CGPoint) scanCGPoint;
- (CGPoint) scanCGPointWithOffset:(CGPoint)off;
@property (readonly) BOOL atEnd;
@property NSUInteger scanLocation;

@property NSUInteger len;
@property const char* bytes;
@end

@implementation pxSVGScanner

+ (instancetype)scannerWithString:(NSString *)string
{
    return [[self alloc] initWithString:string];
}
- (instancetype)initWithString:(NSString *)string
{
    self = [self init];
    self.len = string.length;
    self.bytes = [string cStringUsingEncoding:NSUTF8StringEncoding];
    self.scanLocation = 0;
    return self;
}
- (BOOL)atEnd
{
    return self.scanLocation >= self.len;
}
- (void)skip
{
    static NSCharacterSet *skip; if (!skip) skip = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    while (self.scanLocation < self.len) {
        unichar c = self.bytes[self.scanLocation];
        if (!(
              (c == '\n') ||
              (c == '\r') ||
              (c == '\t') ||
              (c == ' ')
            )) break;
        self.scanLocation++;
    }
}
- (unichar)scanCharacter:(unichar)character
{
    if (self.atEnd || (self.bytes[self.scanLocation] != character)) return 0;
    self.scanLocation++;
    return character;
}
- (unichar)scanCommand
{
    [self skip];
    if (self.atEnd) return 0;
    unichar c = self.bytes[self.scanLocation], l = c;
    if ((l >= 'A') && (l <= 'Z')) l -= 'A'-'a';
    if (!((l == 'm') ||
          (l == 'c') ||
          (l == 's') ||
          (l == 'l') ||
          (l == 'h') ||
          (l == 'v') ||
          (l == 'a') ||
          (l == 'z')
          )) return 0;
    self.scanLocation++;
    [self skip];
    return c;
}
- (CGFloat)scanFloat
{
    [self skip];
    NSRange r;
    r.location = self.scanLocation;
    [self scanCharacter:'-'];
    while (!self.atEnd && ((self.bytes[self.scanLocation] >= '0') && (self.bytes[self.scanLocation] <= '9'))) self.scanLocation++;
    if ([self scanCharacter:'.'] == '.') {
        while (!self.atEnd && ((self.bytes[self.scanLocation] >= '0') && (self.bytes[self.scanLocation] <= '9'))) self.scanLocation++;
    }
    if ([self scanCharacter:'e'] == 'e') {
        [self scanCharacter:'-'];
        while (!self.atEnd && ((self.bytes[self.scanLocation] >= '0') && (self.bytes[self.scanLocation] <= '9'))) self.scanLocation++;
    }
    r.length = self.scanLocation-r.location;
    [self skip];
    char buf[r.length+1];
    memset(buf, 0, r.length+1);
    memcpy(buf, &self.bytes[r.location], r.length);
    return atof(buf);
}
- (BOOL)scanFlag
{
    if (self.atEnd) return NO;
    return self.bytes[self.scanLocation++] == '1';
}
- (CGPoint) scanCGPoint
{
    CGFloat x,y;
    [self scanCharacter:','];
    x = [self scanFloat];
    [self scanCharacter:','];
    y = [self scanFloat];
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
    pxSVGScanner *scanner = [pxSVGScanner scannerWithString:string];
    unichar cmd, lastCmd = 0;
    UIBezierPath *bp = [UIBezierPath new];
    CGPoint p = CGPointZero, c1, c2;
    double d, r, s;
    while (!scanner.atEnd) {
        cmd = [scanner scanCommand];
        if (cmd == 0) {
            if (lastCmd) {
                cmd = lastCmd;
            } else {
                NSLog(@"Unknown character: %@",[string substringWithRange:(NSRange){scanner.scanLocation,1}]);
                break;
            }
        } else lastCmd = cmd;
        switch (cmd) {
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
                [scanner scanCharacter:','];
                d = [scanner scanFloat]; d *= M_PI; d /= 180.f; // a
                [scanner scanCharacter:','];
                [scanner scanFlag];
                [scanner scanCharacter:','];
                [scanner scanFlag];
                c1 = p;
                p = [scanner scanCGPoint];
                c1 = (CGPoint){(c1.x+p.x)/2.f,(c1.y+p.y)/2.f};
                r = sqrt((c2.x-c1.x)*(c2.x-c1.x)+(c2.y-c1.y)*(c2.y-c1.y));
                s = atan2(p.x-c1.x, p.y-c1.y)+M_PI_2;
                [bp addArcWithCenter:c1 radius:r startAngle:s endAngle:s+d clockwise:d>0];
                break;
            case 'a':
                c2 = [scanner scanCGPointWithOffset:p]; // r
                [scanner scanCharacter:','];
                d = [scanner scanFloat]; d *= M_PI; d /= 180.f; // a
                [scanner scanCharacter:','];
                [scanner scanFlag];
                [scanner scanCharacter:','];
                [scanner scanFlag];
                c1 = p;
                p = [scanner scanCGPointWithOffset:p];
                c1 = (CGPoint){(c1.x+p.x)/2.f,(c1.y+p.y)/2.f};
                r = sqrt((c2.x-c1.x)*(c2.x-c1.x)+(c2.y-c1.y)*(c2.y-c1.y));
                s = atan2(p.x-c1.x, p.y-c1.y)+M_PI_2;
                [bp addArcWithCenter:c1 radius:r startAngle:s endAngle:s+d clockwise:d>0];
                break;
            case 'V':
                p.y = [scanner scanFloat];
                [bp addLineToPoint:p];
                break;
            case 'v':
                p.y+= [scanner scanFloat];
                [bp addLineToPoint:p];
                break;
            case 'H':
                p.x = [scanner scanFloat];
                [bp addLineToPoint:p];
                break;
            case 'h':
                p.x+= [scanner scanFloat];
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
                NSLog(@"Unknown command: %c",cmd);
                return nil;
        }
    }
    return bp;
}

- (UIBezierPath*)bezierPolygonWithString:(NSString*)string
{
    pxSVGScanner *scanner = [pxSVGScanner scannerWithString:string];
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
- (CGRect)bounds
{
    if (self.d) return CGRectApplyAffineTransform(self.d.bounds, CATransform3DGetAffineTransform(self.transform));
    return CGRectNull;
}
@end
