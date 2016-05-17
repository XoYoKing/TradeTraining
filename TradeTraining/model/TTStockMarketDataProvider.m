//
//  TTFetchStockData.m
//  TradeTraining
//
//  Created by Amay on 3/18/16.
//  Copyright © 2016 Beddup. All rights reserved.
//

#import "TTStockMarketDataProvider.h"
#import "NSDate+Extension.h"
#import "TTKLineRecord.h"
@interface TTStockMarketDataProvider()

@property(strong, nonatomic) NSURLSession * session;
@property(nonatomic) dispatch_queue_t queue;

@end

@implementation TTStockMarketDataProvider

-(NSURLSession*)session{
    if (!_session) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }
    return _session;
}

-(dispatch_queue_t)queue{
    if (!_queue) {
       _queue = dispatch_queue_create("fetchMarketDataQueue", NULL);
    }
    return _queue;
}

-(void)getHistoryData:(NSString*) completeStockCode
                   From:(NSDate*) fromDate
                     to:(NSDate*) toDate
                   type:(NSString *)dataType
                success:(void (^)(NSArray *records,NSString* kType))success
                failure:(void (^)(NSError *))fail{


    NSString *urlString = [NSString stringWithFormat:@"http://ichart.yahoo.com/table.csv?s=%@&a=%lu&b=%lu&c=%lu&d=%lu&e=%lu&f=%lu&g=%@",completeStockCode,(unsigned long)fromDate.month-1,(unsigned long)fromDate.day,(unsigned long)fromDate.year,(unsigned long)toDate.month-1,(unsigned long)toDate.day,(unsigned long)toDate.year,dataType];


    NSURLSessionDownloadTask* downLoadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
//            fail(error);
        } else{
            
            NSString* csvRecords = [NSString stringWithContentsOfURL:location encoding:NSUTF8StringEncoding error:NULL];
            NSArray* kLineRecords = [csvRecords componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            NSMutableArray * fetchedResult = [@[] mutableCopy];

            for (NSInteger index = kLineRecords.count - 1; index >= 0; index--) {
                NSString* recordString = kLineRecords[index];
                TTKLineRecord *record = [[TTKLineRecord alloc] initWithYahooichartString:recordString stockCode:completeStockCode];
                if (record) {
                    record.previousClosePrice = [(TTKLineRecord*)[fetchedResult firstObject] closePrice];
                    [fetchedResult insertObject:record atIndex:0];
                }
            }
            // the last record would not have the previous close price, so discard it
            [fetchedResult removeLastObject];
            success([fetchedResult copy],dataType);
        }
    }];
    [downLoadTask resume];

}

@end
