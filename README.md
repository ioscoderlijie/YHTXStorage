# YHTXStorage
基于腾讯云存储的封装

## 前言
如果使用临时签名系统，请在上传或者下载之前请提前设置好 ` credential `
```
@property (nonatomic, strong, nullable) QCloudCredential *credential;
```

```
[YHTXStorage sharedStorage].credential.secretID = @"1";
[YHTXStorage sharedStorage].credential.secretKey = @"2";
[YHTXStorage sharedStorage].credential.experationDate = [NSDate dateWithTimeIntervalSinceNow:60 * 60];
[YHTXStorage sharedStorage].credential.token = @"4";
```

## 初始化
在 ` application:didFinishLaunchingWithOptions ` 初始化。
```
[[YHTXStorage sharedStorage] setupStorageServiceWithAppID:@"1257102055" regionName:@"ap-chengdu"];
```

## 上传
```
[[YHTXStorage sharedStorage] uploadFileWithFileName:fileName filePath:path bucketName:@"test-1257102055" progressBlock:^(CGFloat progress) {
        NSLog(@"------上传进度:%.2f",progress);
    } completionBlock:^(NSError * _Nullable error, QCloudUploadObjectResult * _Nullable result) {
        if (error) {
            NSLog(@"😆上传失败:%@",error);
        } else {
            NSLog(@"😆上传成功:%@",result.description);
        }
    }];
```
## 暂停上传
```
[[YHTXStorage sharedStorage] pauseUploadRequestWithBucketName:self.uploadBucketName fileName:self.uploadFileName];
```

## 继续上传
```
[[YHTXStorage sharedStorage] resumeUploadRequestWithBucketName:self.uploadBucketName fileName:self.uploadFileName progressBlock:^(CGFloat progress) {
    NSLog(@"继续上传--进度:%.2f",progress);
} completionBlock:^(NSError * _Nullable error, QCloudUploadObjectResult * _Nullable result) {
    if (error) {
        NSLog(@"😆继续上传--上传失败:%@",error);
        } else {
            NSLog(@"😆继续上传--上传成功:%@",result.description);
    }
}];
```



## 取消上传
```
[[YHTXStorage sharedStorage] cancelUploadRequestWithBucketName:self.uploadBucketName fileName:self.uploadFileName];
```

## 下载
```
[[YHTXStorage sharedStorage] downloadFileWithObjectName:objectName bucketName:@"test-1257102055" savePath:path progressBlock:^(CGFloat progress) {
        NSLog(@"😆:下载进度:%.2f",progress);
    } completionBlock:^(id  _Nullable outputObject, NSError * _Nullable error) {
        if (error) {
            NSLog(@"下载失败:%@",error);
        } else {
            NSLog(@"下载成功:%@",outputObject);
        }
    }];
```
