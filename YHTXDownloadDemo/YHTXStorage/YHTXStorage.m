//
//  YHTXStorage.m
//  QAQ
//
//  Created by apple on 2018/7/31.
//  Copyright © 2018年 SNDO. All rights reserved.
//

#import "YHTXStorage.h"

//是否使用临时签名(测试环境下，可以注释掉改宏，线上环境时，最好不要注释)
//#define    k_YH_USE_TEMPERATE_SECRET
//测试环境下使用，secretID和secretKey写死了，只是用于测试，线上环境不能这样做
#define    kYHTXStorage_SecretID    @"AKIDHZB3lIYppt5UJ372rZ8ZpA3grrimojek"
#define    kYHTXStorage_SecretKey   @"BC7um4EUbv4NbelnzNchaHKFDh6KbjgW"

//static char k_yh_tx_storage_tmp_authentation_key;

@interface YHTXStorage() <QCloudSignatureProvider, QCloudCredentailFenceQueueDelegate>
@property (nonatomic, strong) QCloudCredentailFenceQueue *credentialFenceQueue;
@property (nonatomic, copy) QCloudCredentailFenceQueueContinue continueBlock;
@end

@implementation YHTXStorage
+ (instancetype)sharedStorage{
    static YHTXStorage *storage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        storage = [[self alloc] init];
    });
    return storage;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.credential = [[QCloudCredential alloc] init];
    }
    return self;
}

- (void)setupStorageServiceWithAppID:(NSString *)appID regionName:(NSString *)regionName{
    QCloudServiceConfiguration *configuration = [[QCloudServiceConfiguration alloc] init];
    configuration.appID = appID;
    configuration.signatureProvider = self;
    
    QCloudCOSXMLEndPoint *endPoint = [[QCloudCOSXMLEndPoint alloc] init];
    endPoint.regionName = regionName;
    configuration.endpoint = endPoint;
    
    [QCloudCOSXMLService registerDefaultCOSXMLWithConfiguration:configuration];
    [QCloudCOSTransferMangerService registerDefaultCOSTransferMangerWithConfiguration:configuration];
    
    self.credentialFenceQueue = [[QCloudCredentailFenceQueue alloc] init];
    self.credentialFenceQueue.delegate = self;
}

- (void)uploadFileWithFileName:(NSString *)fileName filePath:(NSString *)filePath bucketName:(NSString *)bucketName progressBlock:(YHTXStorageUploadProgressBlock)progressBlock completionBlock:(YHTXStorageUploadCompletionBlock)completionBlock{
    
    QCloudCOSXMLUploadObjectRequest *uploadRequest = [[QCloudCOSXMLUploadObjectRequest alloc] init];
    uploadRequest.object = fileName;
    uploadRequest.body = [NSURL fileURLWithPath:filePath];
    uploadRequest.bucket = bucketName;
    
    [[QCloudCOSTransferMangerService defaultCOSTransferManager] UploadObject:uploadRequest];
    
    [uploadRequest setSendProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        CGFloat progress = (1.00f * totalBytesSent) / totalBytesExpectedToSend;
        progressBlock ? progressBlock(progress) : nil;
    }];
    [uploadRequest setFinishBlock:^(QCloudUploadObjectResult *result, NSError *error) {
        if (error) {
            completionBlock ? completionBlock(error, nil) : nil;
        } else {
            completionBlock ? completionBlock(nil, result) : nil;
        }
    }];
}


- (void)downloadFileWithObjectName:(NSString *)objectName bucketName:(NSString *)bucketName savePath:(NSString *)savePath progressBlock:(YHTXStorageDownloadProgressBlock)progressBlock completionBlock:(YHTXStorageDownloadCompletionBlock)completionBlock{
    
    QCloudGetObjectRequest *getRequest = [[QCloudGetObjectRequest alloc] init];
    getRequest.bucket = bucketName;
    getRequest.object = objectName;
    if (savePath) {
        getRequest.downloadingURL = [NSURL fileURLWithPath:savePath];
    }
    [[QCloudCOSXMLService defaultCOSXML] GetObject:getRequest];
    
    [getRequest setDownProcessBlock:^(int64_t bytesDownload, int64_t totalBytesDownload, int64_t totalBytesExpectedToDownload) {
        CGFloat progress = (1.00f * totalBytesDownload) / totalBytesExpectedToDownload;
        progressBlock ? progressBlock(progress) : nil;
    }];
    [getRequest setFinishBlock:^(id outputObject, NSError *error) {
        if (error) {
            completionBlock ? completionBlock(nil, error) : nil;
        } else {
            completionBlock ? completionBlock(outputObject, nil) : nil;
        }
    }];
}

#pragma mark - QCloudSignatureProvider
- (void)signatureWithFields:(QCloudSignatureFields *)fileds request:(QCloudBizHTTPRequest *)request urlRequest:(NSMutableURLRequest *)urlRequst compelete:(QCloudHTTPAuthentationContinueBlock)continueBlock{
#ifdef k_YH_USE_TEMPERATE_SECRET
    [self.credentialFenceQueue performAction:^(QCloudAuthentationCreator *creator, NSError *error) {
        if (error) {
            continueBlock(nil, error);
        } else {
            QCloudSignature *signature = [creator signatureForData:urlRequst];
            continueBlock(signature, nil);
        }
    }];
#else
    QCloudCredential* credential = [QCloudCredential new];
    credential.secretID  = kYHTXStorage_SecretID;
    credential.secretKey = kYHTXStorage_SecretKey;
    QCloudAuthentationV5Creator* creator = [[QCloudAuthentationV5Creator alloc] initWithCredential:credential];
    QCloudSignature* signature =  [creator signatureForData:urlRequst];
    continueBlock(signature, nil);
#endif
}
#pragma mark - QCloudCredentailFenceQueueDelegate
- (void)fenceQueue:(QCloudCredentailFenceQueue *)queue requestCreatorWithContinue:(QCloudCredentailFenceQueueContinue)continueBlock{
        QCloudAuthentationV5Creator *creator = [[QCloudAuthentationV5Creator alloc] initWithCredential:self.credential];
        continueBlock(creator, nil);
}
@end


