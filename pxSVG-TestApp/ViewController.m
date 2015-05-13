//
//  ViewController.m
//  pxSVG
//
//  Created by Yury Popov on 12 мая.
//  Copyright (c) 2015 PhoeniX. All rights reserved.
//

#import "ViewController.h"
#import <pxSVG/pxSVG.h>

@interface SVGCollectionCell : UICollectionViewCell <pxSVGViewDelegate>
@property (nonatomic) NSURL *SVGURL;
@property (weak) pxSVGView *svgView;
@end

@implementation SVGCollectionCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.backgroundColor = [UIColor whiteColor];
    pxSVGView *sv = [[pxSVGView alloc] initWithFrame:self.contentView.bounds];
    sv.svgDelegate = self;
    sv.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:_svgView=sv];
    self.clipsToBounds = YES;
    return self;
}

- (void)svgViewDidLoadImage:(pxSVGView *)svgView
{
    NSLog(@"load %@",self.SVGURL);
}

- (void)svgView:(pxSVGView *)svgLayer didFailedLoad:(NSError *)error
{
    NSLog(@"err %@ %@",self.SVGURL,error);
}

- (void)setSVGURL:(NSURL *)SVGURL
{
    _SVGURL = SVGURL;
    [self.svgView loadURL:SVGURL];
}

@end

@interface ViewController () <UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout>
@property NSArray *images;
@end

@implementation ViewController

- (instancetype)init
{
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.itemSize = (CGSize){159,159};
    layout.sectionInset = UIEdgeInsetsZero;
    layout.minimumInteritemSpacing = 1;
    layout.minimumLineSpacing = 1;
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    self = [super initWithCollectionViewLayout:layout];
    self.images = [NSBundle URLsForResourcesWithExtension:@"svg" subdirectory:nil inBundleWithURL:[NSBundle mainBundle].bundleURL];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.collectionView.backgroundColor = [UIColor grayColor];
    [self.collectionView registerClass:[SVGCollectionCell class] forCellWithReuseIdentifier:@"cell"];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.images.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SVGCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    [cell setSVGURL:self.images[indexPath.item]];
    return cell;
}

@end
