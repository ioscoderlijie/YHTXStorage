//
//  YHTXStorage.m
//  QAQ
//
//  Created by apple on 2018/7/31.
//  Copyright © 2018年 SNDO. All rights reserved.
//

#import "YHTXStorage.h"
#import <CommonCrypto/CommonCrypto.h>

//是否使用临时签名(测试环境下，可以注释掉改宏，线上环境时，最好不要注释)
//#define    k_YH_USE_TEMPERATE_SECRET
//测试环境下使用，secretID和secretKey写死了，只是用于测试，线上环境不能这样做
#define    kYHTXStorage_SecretID    @"AKIDHZB3lIYppt5UJ372rZ8ZpA3grrimojek"
#define    kYHTXStorage_SecretKey   @"BC7um4EUbv4NbelnzNchaHKFDh6KbjgW"

#define kYHDownloadError(_code_,_msg_) [NSError errorWithDomain:@"com.error.yinhe.tx_download" code:_code_ userInfo:@{NSLocalizedDescriptionKey:_msg_}]

//static char k_yh_tx_storage_tmp_authentation_key;

NSInteger const kYHTXDownloadNoFilePathErrorKey = 1000;
NSInteger const kYHTXDownloadDownloadingErrorKey = 1001;
NSInteger const kYHTXUploadUploadingErrorKey = 1002;
NSInteger const kYHTXUploadNoFilePathErrorKey = 1003;

@interface YHTXStorage() <QCloudSignatureProvider, QCloudCredentailFenceQueueDelegate>
@property (nonatomic, strong) QCloudCredentailFenceQueue *credentialFenceQueue;
@property (nonatomic, copy) QCloudCredentailFenceQueueContinue continueBlock;

@property (nonatomic, strong) NSMutableDictionary<NSString *, QCloudCOSXMLUploadObjectRequest *> *allUploadRequests;
@property (nonatomic, strong) NSMutableDictionary<NSString *, QCloudCOSXMLUploadObjectResumeData> *allUploadResumeDatas;
@property (nonatomic, strong) NSMutableDictionary<NSString *, QCloudGetObjectRequest *> *allDownloadRequests;

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
        self.allUploadRequests = [NSMutableDictionary dictionary];
        self.allUploadResumeDatas = [NSMutableDictionary dictionary];
        self.allDownloadRequests = [NSMutableDictionary dictionary];
        
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
    
    [QCloudLogger sharedLogger].logLevel = QCloudLogLevelNone;
    
    self.credentialFenceQueue = [[QCloudCredentailFenceQueue alloc] init];
    self.credentialFenceQueue.delegate = self;
}
#pragma mark - Upload
- (void)uploadFileWithFileName:(NSString *)fileName filePath:(NSString *)filePath bucketName:(NSString *)bucketName progressBlock:(YHTXStorageUploadProgressBlock)progressBlock completionBlock:(YHTXStorageUploadCompletionBlock)completionBlock{
    //上传之前，先检查本地是否存在该文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        completionBlock ? completionBlock(kYHDownloadError(kYHTXUploadNoFilePathErrorKey, @"文件不存在"), nil) : nil;
        return;
    }
    //判断是否正在上传
    NSString *key = [self getKeyWithbucketName:bucketName fileName:fileName];
    if ([self.allUploadRequests.allKeys containsObject:key]) {
        QCloudCOSXMLUploadObjectRequest *rq = self.allUploadRequests[key];
        if (!rq.finished) {
            rq.sendProcessBlock = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
                static CGFloat lastProgress2 = 0.00;
                CGFloat progress = (1.00f * totalBytesSent) / totalBytesExpectedToSend;
                if (progress - lastProgress2 >= 0.1 || progress >= 1.00) {
                    lastProgress2 = progress;
                    progressBlock ? progressBlock(lastProgress2) : nil;
                }
                if (lastProgress2 >= 1.00) {
                    lastProgress2 = 0.00;
                }
            };
            completionBlock ? completionBlock(kYHDownloadError(kYHTXUploadUploadingErrorKey, @"正在上传"), nil) : nil;
            return;
        }
    }
    
    QCloudCOSXMLUploadObjectRequest *uploadRequest = [[QCloudCOSXMLUploadObjectRequest alloc] init];
    uploadRequest.object = fileName;
    uploadRequest.body = [NSURL fileURLWithPath:filePath];
    uploadRequest.bucket = bucketName;
    
    [[QCloudCOSTransferMangerService defaultCOSTransferManager] UploadObject:uploadRequest];
    
    [self uploadWithUploadRequest:uploadRequest progressBlock:progressBlock completionBlock:completionBlock];
}
- (void)uploadWithUploadRequest:(QCloudCOSXMLUploadObjectRequest *)uploadRequest progressBlock:(YHTXStorageUploadProgressBlock)progressBlock completionBlock:(YHTXStorageUploadCompletionBlock)completionBlock{
    
    NSString *key = [self getKeyWithbucketName:uploadRequest.bucket fileName:uploadRequest.object];
    [self.allUploadRequests setObject:uploadRequest forKey:key];
    
    [uploadRequest setSendProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        static CGFloat lastProgress4 = 0.00;
        CGFloat progress = (1.00f * totalBytesSent) / totalBytesExpectedToSend;
        if (progress - lastProgress4 >= 0.1 || progress >= 1.00) {
            lastProgress4 = progress;
            progressBlock ? progressBlock(lastProgress4) : nil;
        }
        if (lastProgress4 >= 1.00) {
            lastProgress4 = 0.00;
        }
    }];
    
    [uploadRequest setFinishBlock:^(QCloudUploadObjectResult *result, NSError *error) {
        if (error) {
            completionBlock ? completionBlock(error, nil) : nil;
        } else {
            [self removeUploadObjectWithKey:key];
            [self removeResumeDataWithKey:key];
            completionBlock ? completionBlock(nil, result) : nil;
        }
    }];
}
#pragma mark - Pause Upload Request
- (QCloudCOSXMLUploadObjectResumeData)pauseUploadRequest:(QCloudCOSXMLUploadObjectRequest *)uploadRequest{
    NSError *error = nil;
    QCloudCOSXMLUploadObjectResumeData data = [uploadRequest cancelByProductingResumeData:&error];
    if (!error) {
        NSString *key = [self getKeyWithbucketName:uploadRequest.bucket fileName:uploadRequest.object];
        [self.allUploadResumeDatas setObject:data forKey:key];
    }
    return data;
}
- (void)pauseUploadRequestWithBucketName:(NSString *)bucketName fileName:(NSString *)fileName{
    NSString *key = [self getKeyWithbucketName:bucketName fileName:fileName];
    if ([self.allUploadRequests.allKeys containsObject:key]) {
         QCloudCOSXMLUploadObjectRequest *rq = self.allUploadRequests[key];
        [self pauseUploadRequest:rq];
    }
}
#pragma mark - Resume Upload
- (void)resumeUploadRequestWithResumeData:(QCloudCOSXMLUploadObjectResumeData)resumeData progressBlock:(YHTXStorageUploadProgressBlock)progressBlock completionBlock:(YHTXStorageUploadCompletionBlock)completionBlock{
    if (!resumeData) {
        return;
    }
    QCloudCOSXMLUploadObjectRequest *uploadRequest = [QCloudCOSXMLUploadObjectRequest requestWithRequestData:resumeData];
    if (!uploadRequest) {
        return;
    }
    [self uploadWithUploadRequest:uploadRequest progressBlock:progressBlock completionBlock:completionBlock];
    [[QCloudCOSTransferMangerService defaultCOSTransferManager] UploadObject:uploadRequest];
}
- (void)resumeUploadRequestWithBucketName:(NSString *)bucketName fileName:(NSString *)fileName progressBlock:(YHTXStorageUploadProgressBlock)progressBlock completionBlock:(YHTXStorageUploadCompletionBlock)completionBlock{
    NSString *key = [self getKeyWithbucketName:bucketName fileName:fileName];
    if ([self.allUploadResumeDatas.allKeys containsObject:key]) {
        QCloudCOSXMLUploadObjectResumeData data = self.allUploadResumeDatas[key];
        [self resumeUploadRequestWithResumeData:data progressBlock:progressBlock completionBlock:completionBlock];
    }
}
#pragma mark - Cancel Upload Request
- (void)cancelUploadRequest:(QCloudCOSXMLUploadObjectRequest *)uploadRequest{
    if (!uploadRequest) {
        return;
    }
    [uploadRequest abort:^(id outputObject, NSError *error) {
        @synchronized(self){
            [self removeUploadObjectWithRequst:uploadRequest];
        }
    }];
}
- (void)cancelUploadRequestWithBucketName:(NSString *)bucketName fileName:(NSString *)fileName{
    NSString *key = [self getKeyWithbucketName:bucketName fileName:fileName];
    if ([self.allUploadRequests.allKeys containsObject:key]) {
        QCloudCOSXMLUploadObjectRequest *rq = self.allUploadRequests[key];
        [self cancelUploadRequest:rq];
    }
}


#pragma mark - Download
- (void)downloadFileWithObjectName:(NSString *)objectName bucketName:(NSString *)bucketName savePath:(NSString *)savePath progressBlock:(YHTXStorageDownloadProgressBlock)progressBlock completionBlock:(YHTXStorageDownloadCompletionBlock)completionBlock{
    //判断路径是否存在
    if (!savePath || savePath.length == 0) {
        completionBlock ? completionBlock(nil, nil, kYHDownloadError(kYHTXDownloadNoFilePathErrorKey, @"文件路径不存在")) : nil;
        return;
    }
    //判断路径下是否存在文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:savePath]) {
        completionBlock ? completionBlock(nil, savePath, nil) : nil;
        return;
    }
    //判断是否正在下载，如果正在下载，return
    NSString *key = [self getKeyWithbucketName:bucketName fileName:objectName];
    if ([self.allDownloadRequests.allKeys containsObject:key]) {
        QCloudGetObjectRequest *rq = self.allDownloadRequests[key];
        if (!rq.finished) {
            rq.downProcessBlock = ^(int64_t bytesDownload, int64_t totalBytesDownload, int64_t totalBytesExpectedToDownload) {
                static CGFloat lastProgress = 0.00;
                CGFloat progress = (1.00f * totalBytesDownload) / totalBytesExpectedToDownload;
                if (progress - lastProgress >= 0.1 || progress >= 1.00) {
                    lastProgress = progress;
                    progressBlock ? progressBlock(lastProgress) : nil;
                }
                if (lastProgress >= 1.00) {
                    lastProgress = 0.00;
                }
            };
            completionBlock ? completionBlock(nil, nil, kYHDownloadError(kYHTXDownloadDownloadingErrorKey, @"正在下载")) : nil;
            return;
        }
    }
    
    QCloudGetObjectRequest *getRequest = [[QCloudGetObjectRequest alloc] init];
    getRequest.bucket = bucketName;
    getRequest.object = objectName;
    getRequest.downloadingURL = [NSURL fileURLWithPath:savePath];
    
    [[QCloudCOSXMLService defaultCOSXML] GetObject:getRequest];
    
    [self.allDownloadRequests setObject:getRequest forKey:key];
    
    [getRequest setDownProcessBlock:^(int64_t bytesDownload, int64_t totalBytesDownload, int64_t totalBytesExpectedToDownload) {
        static CGFloat lastProgress1 = 0.00;
        CGFloat progress = (1.00f * totalBytesDownload) / totalBytesExpectedToDownload;
        if (progress - lastProgress1 >= 0.1 || progress >= 1.00) {
            lastProgress1 = progress;
            progressBlock ? progressBlock(lastProgress1) : nil;
        }
        if (lastProgress1 >= 1.00) {
            lastProgress1 = 0.00;
        }
    }];
    [getRequest setFinishBlock:^(id outputObject, NSError *error) {
        [self removeDownloadObjetWithKey:key];
        if (error) {
            completionBlock ? completionBlock(nil , nil ,error) : nil;
        } else {
            completionBlock ? completionBlock(outputObject, savePath, nil) : nil;
        }
    }];
}
- (BOOL)isDownloadingWithObjectName:(NSString *)objectName bucketName:(NSString *)bucketName{
    BOOL isDownload = NO;
    NSString *key = [self getKeyWithbucketName:bucketName fileName:objectName];
    if ([self.allDownloadRequests.allKeys containsObject:key]) {
        QCloudGetObjectRequest *rq = self.allDownloadRequests[key];
        if (!rq.finished) {
            isDownload = NO;
        }
    }
    return isDownload;
}

#pragma mark - methods
- (NSString *)md5With:(NSString *)string{
    const char *cStr = [string UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}
- (NSString *)getKeyWithbucketName:(NSString *)bucketName fileName:(NSString *)fileName{
    NSString *preString = [NSString stringWithFormat:@"%@-%@",bucketName, fileName];
    return [self md5With:preString];
}
- (void)removeDownloadObjetWithKey:(NSString *)key{
    if ([self.allDownloadRequests.allKeys containsObject:key]) {
        [self.allDownloadRequests removeObjectForKey:key];
    }
}
- (void)removeUploadObjectWithKey:(NSString *)key{
    if ([self.allUploadRequests.allKeys containsObject:key]) {
        [self.allUploadRequests removeObjectForKey:key];
    }
}
- (void)removeUploadObjectWithRequst:(QCloudCOSXMLUploadObjectRequest *)request{
    NSString *key = [self getKeyWithbucketName:request.bucket fileName:request.object];
    [self removeUploadObjectWithKey:key];
    [self removeResumeDataWithKey:key];
}
- (void)removeResumeDataWithKey:(NSString *)key{
    if ([self.allUploadResumeDatas.allKeys containsObject:key]) {
        [self.allUploadResumeDatas removeObjectForKey:key];
    }
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


