//
//  TTKLineChart.m
//  TradeTraining
//
//  Created by Amay on 4/6/16.
//  Copyright © 2016 Beddup. All rights reserved.
//

#import "TTKLineChart.h"
#import "TTCandleChart.h"
#import "TTRecordInfoView.h"
#import "NSDate+Extension.h"
#import "TTDefines.h"

@interface TTKLineChart()<TTCandleChartDelegate>

@property(weak, nonatomic)TTRecordInfoView* recordInfoView;
@property(weak, nonatomic)UILabel* maDisplayLabel;
@property(weak,nonatomic) TTCandleChart* candleChart;
@property(strong,nonatomic)NSArray* priceLabels;
@property(strong,nonatomic)NSMutableArray* dateLabels;

@end


@implementation TTKLineChart

#pragma mark - properties
-(void)setKLineType:(NSString *)kLineType{

    if (_kLineType != kLineType) {

        // if k line type change, records need reloaded
        _kLineType = kLineType;
        self.candleChart.kLineType = kLineType;
        self.records = nil;
        [self feedMoreDateCompletionHandler:nil];
    }
}

-(void)setRecords:(NSArray *)records{

    _records = records;
    self.candleChart.records = records;
    if (records.count <= 0) {
        [self.priceLabels makeObjectsPerformSelector:@selector(setText:) withObject:nil];
    }

}

-(void)setStockCode:(NSString *)stockCode{

    _stockCode = stockCode;
    self.records = nil;
    [self feedMoreDateCompletionHandler:nil];

}

-(void)setShowDate:(BOOL)showDate{
    _showDate = showDate;
    self.recordInfoView.showDate = showDate;
    [self.dateLabels makeObjectsPerformSelector:@selector(setHidden:) withObject:@(YES)];
}
#pragma mark - update indicator

static CGFloat RecordInfoDisplayWidth = 140;
static CGFloat RecordInfoDisplayHeight = 160;
static CGFloat MADisplayZoneHeight = 25;

#pragma mark - TTCandleChartDelegate
-(void)focusedRecord:(TTKLineRecord *)focusedRecord inRightHalfArea:(BOOL)rightHalf{
    // update the ma display label and adjust recordInfoView frame
    if (focusedRecord) {
        
        self.recordInfoView.record = focusedRecord;

        // update ma display info and focused record info
        NSMutableAttributedString* maString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"MA5: %.2f   ",focusedRecord.MA5] attributes:@{NSForegroundColorAttributeName:MA5Color}];
        [maString appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"MA10: %.2f   ",focusedRecord.MA10] attributes:@{NSForegroundColorAttributeName:MA10Color}]];
        [maString appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"MA20: %.2f   ",focusedRecord.MA20] attributes:@{NSForegroundColorAttributeName:MA20Color}]];
        [self.maDisplayLabel setAttributedText:maString];

        // frame
        self.recordInfoView.center = rightHalf ? CGPointMake(RecordInfoDisplayWidth / 2, RecordInfoDisplayHeight / 2) : CGPointMake(CGRectGetWidth(self.bounds) - RecordInfoDisplayWidth / 2, RecordInfoDisplayHeight / 2);
        NSLog(@"frame after:%@",NSStringFromCGRect(self.recordInfoView.frame));
        self.recordInfoView.hidden = NO;

    }else{

        self.recordInfoView.hidden = YES;
        [self.maDisplayLabel setAttributedText:nil];
    }
}

-(void)pricenRangeChangedWithMaxPrice:(float)max minPrice:(float)min{
    // update the price labels
    float delta = (max - min) / AxisPriceZoneCount;
    for (NSInteger index = 0; index < self.priceLabels.count; index++) {
        UILabel* label = self.priceLabels[index];
        label.text = [NSString stringWithFormat:@"%.2f",max - delta * (index + 1)];
    }

}
-(void)dateMeterChanged:(NSDictionary* )dateStringAndPointX{

    [self.dateLabels makeObjectsPerformSelector:@selector(setHidden:) withObject:@(YES)];

    if (!self.showDate) {
        return;
    }
    if (dateStringAndPointX.count <= 0) {
        return;
    }

    NSArray* dateStrings = [dateStringAndPointX allKeys];
    for (NSInteger index = 0; index < dateStrings.count; index++) {
        float x =[(NSNumber *)dateStringAndPointX[dateStrings[index]] floatValue];
        if (self.dateLabels.count <= index) {
            UILabel* label = [[UILabel alloc]initWithFrame:CGRectZero];
            label.center = CGPointMake(x,CGRectGetHeight(self.bounds) * KlineAreaHeightRatio + 8);
            label.bounds = CGRectMake(0, 0, 60, KlineAndVolumSpace);
            label.text = dateStrings[index];
            label.textColor = [UIColor darkGrayColor];
            label.font = [UIFont systemFontOfSize:12];
            label.textAlignment = NSTextAlignmentCenter;
            [self addSubview:label];
            [self.dateLabels addObject:label];
        }else{
            UILabel* label = self.dateLabels[index];
            label.text = dateStrings[index];
            label.center = CGPointMake(x,CGRectGetHeight(self.bounds) * KlineAreaHeightRatio + 8);
            label.hidden = NO;
        }
    }


}

-(void)feedMoreDateCompletionHandler:(void (^)())completionHandler{

    // fetch 1 more year for day k , 5 years for week k, and all for month k
    NSDate* fromDate = nil;
    NSDate* now = [NSDate date];

    NSDate* earlistDate = self.records.count > 0 ? ((TTKLineRecord*)[self.records lastObject]).date : now;
    if ([self.kLineType isEqualToString:TTKlineTypeDay]) {
        fromDate  = [earlistDate offsetYears:-1];
    }else if ([self.kLineType isEqualToString:TTKlineTypeWeek]){
        fromDate  = [earlistDate offsetYears:-5];
    }else{
        fromDate = [NSDate distantPast];
    }

    [self.dataSource getRecordsOfStock:self.stockCode
                                  From:fromDate
                                    to:now
                             kLineType:self.kLineType
                      completionHander:^(NSArray *records,NSString* kType) {
                          dispatch_async(dispatch_get_main_queue(), ^{

                              if ([self.kLineType isEqualToString:kType]) {
                                  // during the data fetching, user may change the k type. in such situation, the returned record should be discarded 
                                  if (completionHandler) {
                                      completionHandler();
                                  }
                                  self.records = records;
                              }
                          });
                      }];
}


#pragma  mark - setup
-(void)layoutSubviews{

    self.candleChart.frame = self.bounds;

    self.maDisplayLabel.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), MADisplayZoneHeight);
    for (NSInteger index = 0; index < self.priceLabels.count; index++) {
        UILabel* label = self.priceLabels[index];
        label.frame = CGRectMake(0, KlineAreaHeightRatio * CGRectGetHeight(self.bounds) / AxisPriceZoneCount * (index + 1) - 15, 60, 15);
    }
    
}
-(void)awakeFromNib{
    [self setup];
}


-(void)setup{

    _kLineType = TTKlineTypeDay;

    [self setTranslatesAutoresizingMaskIntoConstraints:NO];

    self.layer.borderWidth = 0.5;
    self.layer.borderColor = [UIColor lightGrayColor].CGColor;

    // candle chart
    TTCandleChart* candleChart = [[TTCandleChart alloc] initWithFrame:self.bounds];
    [self addSubview:candleChart];
    candleChart.delegate = self;
    candleChart.kLineType = _kLineType;
    _candleChart = candleChart;

    // price label
    NSMutableArray* labels = [@[] mutableCopy];
    for (NSInteger index = 1; index < AxisPriceZoneCount ; index++) {
        UILabel* priceLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 15)];
        priceLabel.font = [UIFont systemFontOfSize:12];
        priceLabel.textColor = [UIColor lightGrayColor];
        [self addSubview:priceLabel];
        [labels addObject:priceLabel];
    }
    _priceLabels = [labels copy];

    _dateLabels = [@[] mutableCopy];

    //ma info label
    UILabel* MAInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.bounds), MADisplayZoneHeight)];
    MAInfoLabel.layer.backgroundColor = [UIColor clearColor].CGColor;

    MAInfoLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [self addSubview:MAInfoLabel];
    self.maDisplayLabel = MAInfoLabel;

    //focused record info
    TTRecordInfoView* view = [[[NSBundle mainBundle] loadNibNamed:@"TTRecordInfoView" owner:nil options:nil] lastObject];
    view.bounds = CGRectMake(0,0, RecordInfoDisplayWidth, RecordInfoDisplayHeight);
    [self addSubview:view];
    view.hidden = YES;
    self.recordInfoView = view;

    self.showDate = YES;

}
-(instancetype)initWithFrame:(CGRect)frame{
    self=[super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

@end
