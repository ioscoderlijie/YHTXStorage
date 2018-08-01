//
//  YHTXStorage.h
//  QAQ
//
//  Created by apple on 2018/7/31.
//  Copyright © 2018年 SNDO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QCloudCore/QCloudCore.h>
#import <QCloudCOSXML/QCloudCOSXML.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^YHTXStorageUploadProgressBlock)(CGFloat progress);
typedef void(^YHTXStorageUploadCompletionBlock)(NSError *_Nullable error,QCloudUploadObjectResult *_Nullable result);

typedef void(^YHTXStorageDownloadProgressBlock)(CGFloat progress);
typedef void(^YHTXStorageDownloadCompletionBlock)(id _Nullable outputObject,NSString *_Nullable path,NSError *_Nullable error);

FOUNDATION_EXTERN NSInteger const kYHTXDownloadNoFilePathErrorKey;
FOUNDATION_EXTERN NSInteger const kYHTXDownloadDownloadingErrorKey;

FOUNDATION_EXTERN NSInteger const kYHTXUploadUploadingErrorKey;
FOUNDATION_EXTERN NSInteger const kYHTXUploadNoFilePathErrorKey;

@interface YHTXStorage : NSObject
+ (instancetype)sharedStorage;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, QCloudCOSXMLUploadObjectRequest *> *allUploadRequests;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, QCloudCOSXMLUploadObjectResumeData> *allUploadResumeDatas;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, QCloudGetObjectRequest *> *allDownloadRequests;


/**
 *
 虽然在本地提供了永久的 SecretId 和 SecretKey 来生成签名的接口，但请注意，将永久的 SecretId 和SecretKey 存储在本地是非常危险的行为，容易造成泄露引起不必要的损失。因此基于安全性的考虑，建议您在服务器端实现签名的过程。
 
 推荐您在自己的签名服务器内接入腾讯云的 CAM（Cloud Access Manager，访问管理）来实现整个签名流程。
 
 签名服务器接入 CAM 系统后，当客户端向签名服务器端请求签名时，签名服务器端会向 CAM 系统请求临时证书，然后返回给客户端。CAM 系统会根据您的永久 SecretId 和 SecretKey 来生成临时的 Secret ID，Secret Key 和临时 Token 来生成签名，可以最大限度地提高安全性。终端收到这些临时密钥的信息后，通过它们构建一个 QCloudCredential 对象，然后通过这个 QCloudCredentail 对象生成 QCloudAuthentationCreator，最后通过使用这个 Creator 来生成包含签名信息的 QCloudSignature 对象
 *
 */
//@property (nonatomic, copy) YHTXStorageTmpAuthentationBlock tmpAuthentationBlock;
@property (nonatomic, strong, nullable) QCloudCredential *credential;

/**
 * 在 application:didFinishLaunchingWithOptions 初始化
 */
- (void)setupStorageServiceWithAppID:(NSString *)appID regionName:(NSString *)regionName;

#pragma mark - Uplaod
/**
 * 上传文件的方法
 */
- (void)uploadFileWithFileName:(NSString *)fileName filePath:(NSString *)filePath bucketName:(NSString *)bucketName progressBlock:(nullable YHTXStorageUploadProgressBlock)progressBlock completionBlock:(nullable YHTXStorageUploadCompletionBlock)completionBlock;

#pragma mark - Pause Upload Request
- (nullable QCloudCOSXMLUploadObjectResumeData)pauseUploadRequest:(QCloudCOSXMLUploadObjectRequest *)uploadRequest;
- (void)pauseUploadRequestWithBucketName:(NSString *)bucketName fileName:(NSString *)fileName;
#pragma mark - Resume Upload
- (void)resumeUploadRequestWithResumeData:(QCloudCOSXMLUploadObjectResumeData)resumeData progressBlock:(nullable YHTXStorageUploadProgressBlock)progressBlock completionBlock:(nullable YHTXStorageUploadCompletionBlock)completionBlock;
- (void)resumeUploadRequestWithBucketName:(NSString *)bucketName fileName:(NSString *)fileName progressBlock:(nullable YHTXStorageUploadProgressBlock)progressBlock completionBlock:(nullable YHTXStorageUploadCompletionBlock)completionBlock;
#pragma mark - Cancel Upload Request
- (void)cancelUploadRequest:(QCloudCOSXMLUploadObjectRequest *)uploadRequest;
- (void)cancelUploadRequestWithBucketName:(NSString *)bucketName fileName:(NSString *)fileName;

#pragma mark - Download
/**
 * 下载文件的方法
 * 当savePath存在，并且该路径下有图片，则直接返回沙盒图片，不会走SDK的下载方法
 * savePath最好不要为空
 */
- (void)downloadFileWithObjectName:(NSString *)objectName bucketName:(NSString *)bucketName savePath:(nullable NSString *)savePath progressBlock:(nullable YHTXStorageDownloadProgressBlock)progressBlock completionBlock:(nullable YHTXStorageDownloadCompletionBlock)completionBlock;
/**
 * 是否正在下载
 */
- (BOOL)isDownloadingWithObjectName:(NSString *)objectName bucketName:(NSString *)bucketName;

#pragma mark - Cancel Download Request


@end
NS_ASSUME_NONNULL_END
