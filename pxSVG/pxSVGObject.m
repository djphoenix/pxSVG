//
//  pxSVGObject.m
//  pxSVG
//
//  Created by Yury Popov on 12.05.15.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "pxSVGObject.h"

@implementation pxSVGObject
+ (CATransform3D) transformFromString:(NSString*)string
{
    CATransform3D tr = CATransform3DIdentity;
    if (!string.length) return tr;
    NSScanner *sc = [NSScanner scannerWithString:string];
    sc.charactersToBeSkipped = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *op; double p[6]; int i;
    while (!sc.atEnd) {
        [sc scanUpToString:@"(" intoString:&op];
        [sc scanString:@"(" intoString:nil];
        i=0;
        while ([sc scanDouble:&p[i++]]) [sc scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@" ,"] intoString:nil];
        i--;
        [sc scanString:@")" intoString:nil];
        
        if ([op isEqualToString:@"scale"]) {
            switch (i) {
                case 1:
                    tr = CATransform3DScale(tr, p[0], p[0], 1);
                    break;
                case 2:
                    tr = CATransform3DScale(tr, p[0], p[1], 1);
                    break;
                default: NSLog(@"Invalid number of operands for %@: %@",op,@(i)); break;
            }
        } else if ([op isEqualToString:@"translate"]) {
            switch (i) {
                case 2:
                    tr = CATransform3DTranslate(tr, p[0], p[1], 0);
                    break;
                default: NSLog(@"Invalid number of operands for %@: %@",op,@(i)); break;
            }
        } else if ([op isEqualToString:@"matrix"]) {
            switch (i) {
                case 6:
                    tr = CATransform3DConcat(tr, CATransform3DMakeAffineTransform(CGAffineTransformMake(p[0], p[1], p[2], p[3], p[4], p[5])));
                    break;
                default: NSLog(@"Invalid number of operands for %@: %@",op,@(i)); break;
            }
        } else {
            NSLog(@"Unknown transform: %@",op);
        }
    }
    return tr;
}
+ (UIColor*) colorWithSVGColor:(NSString*)string
{
    if (!string) return nil;
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([string isEqualToString:@"none"]) return [UIColor clearColor];
    if ([string isEqualToString:@"black"]) return [UIColor blackColor];
    if ([string isEqualToString:@"white"]) return [UIColor whiteColor];
    NSScanner *sc = [NSScanner scannerWithString:[string lowercaseString]];
    if ([sc scanString:@"#" intoString:nil]) {
        unsigned int cl;
        [sc scanHexInt:&cl];
        float r,g,b;
        switch (string.length) {
            case 4:
                b = (cl & 0xF)<<4; cl >>= 4;
                g = (cl & 0xF)<<4; cl >>= 4;
                r = (cl & 0xF)<<4; cl >>= 4;
                break;
            case 7:
                b = cl & 0xFF; cl >>= 8;
                g = cl & 0xFF; cl >>= 8;
                r = cl & 0xFF; cl >>= 8;
                break;
                
            default:
                NSLog(@"Invalid hex color: %@",string);
                return nil;
        }
        r /= 255.f;
        g /= 255.f;
        b /= 255.f;
        return [UIColor colorWithRed:r green:g blue:b alpha:1];
    }
    NSLog(@"Unknown color: %@",string);
    return nil;
}
- (void)loadAttributes:(NSDictionary *)attributes
{
    NSMutableDictionary *ma = [attributes mutableCopy];
    if ([attributes objectForKey:@"style"]) {
        for (NSString *s in [[attributes objectForKey:@"style"] componentsSeparatedByString:@";"]) {
            NSUInteger sep = [s rangeOfString:@":"].location;
            if (sep == NSNotFound) continue;
            NSString *k = [[s substringToIndex:sep] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *v = [[s substringFromIndex:sep+1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [ma setObject:v forKey:k];
        }
    }
    self.id = [ma objectForKey:@"id"];
    if ([[ma objectForKey:@"fill"] hasPrefix:@"url("]) {
        NSString *u = [[ma objectForKey:@"fill"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        u = [[u substringWithRange:NSMakeRange(3, u.length-4)] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r\t ()#"]];
        self.fillDef = u;
    } else self.fillColor = [self.class colorWithSVGColor:[ma objectForKey:@"fill"]];
    if ([ma objectForKey:@"clip-path"]) {
        NSString *u = [[ma objectForKey:@"clip-path"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        u = [[u substringWithRange:NSMakeRange(3, u.length-4)] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r\t ()#"]];
        self.clipDef = u;
    }
    self.strokeColor = [self.class colorWithSVGColor:[ma objectForKey:@"stroke"]];
    self.strokeWidth = [ma objectForKey:@"stroke-width"]?[[ma objectForKey:@"stroke-width"] doubleValue]:NAN;
    self.transform = [self.class transformFromString:[ma objectForKey:@"transform"]];
    self.opacity = [ma objectForKey:@"opacity"]?[[ma objectForKey:@"opacity"] doubleValue]:1;
    CGFloat a = NAN;
    if (self.fillColor) [self.fillColor getWhite:nil alpha:&a];
    self.fillOpacity = [ma objectForKey:@"fill-opacity"]?[[ma objectForKey:@"fill-opacity"] doubleValue]:a;
}
- (void)setSubnodes:(NSArray *)subnodes { }
- (CGRect)bounds
{
    return CGRectNull;
}
@end
