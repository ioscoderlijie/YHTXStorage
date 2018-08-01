//
//  ViewController.m
//  YHTXDownloadDemo
//
//  Created by apple on 2018/7/31.
//  Copyright © 2018年 yinhe. All rights reserved.
//

#import "ViewController.h"
#import "YHTXStorage.h"
@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@property (nonatomic, copy) NSString *uploadBucketName;
@property (nonatomic, copy) NSString *uploadFileName;
@property (weak, nonatomic) IBOutlet UIButton *pauseButton;
@property (nonatomic, assign) BOOL isFinedUplaod;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isFinedUplaod = YES;
    [self.pauseButton setTitle:@"暂停上传" forState:UIControlStateNormal];
    [self.pauseButton setTitle:@"继续上传" forState:UIControlStateSelected];
    
    //模拟从服务器获取临时签名
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [YHTXStorage sharedStorage].credential.secretID = @"1";
        [YHTXStorage sharedStorage].credential.secretKey = @"2";
        [YHTXStorage sharedStorage].credential.experationDate = [NSDate dateWithTimeIntervalSinceNow:60 * 60];
        [YHTXStorage sharedStorage].credential.token = @"4";
    });
}
- (IBAction)uploadAction:(id)sender {
    if (!self.isFinedUplaod) {
        NSLog(@"正在上传，请等待上个任务上传完成");
        return;
    }
    if ([UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary]) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:nil];
    }
}
- (IBAction)pauseUploadAction:(id)sender {
    UIButton *btn = sender;
    btn.selected = !btn.selected;
    if (btn.selected) {
        NSLog(@"暂停上传");
        [[YHTXStorage sharedStorage] pauseUploadRequestWithBucketName:self.uploadBucketName fileName:self.uploadFileName];
    } else {
        NSLog(@"继续上传");
        [[YHTXStorage sharedStorage] resumeUploadRequestWithBucketName:self.uploadBucketName fileName:self.uploadFileName progressBlock:^(CGFloat progress) {
            NSLog(@"继续上传--进度:%.2f",progress);
        } completionBlock:^(NSError * _Nullable error, QCloudUploadObjectResult * _Nullable result) {
            self.isFinedUplaod = YES;
            if (error) {
                NSLog(@"😆继续上传--上传失败:%@",error);
            } else {
                NSLog(@"😆继续上传--上传成功:%@",result.description);
            }
        }];
    }
    
}
- (IBAction)cancelUploadAction:(id)sender {
    [[YHTXStorage sharedStorage] cancelUploadRequestWithBucketName:self.uploadBucketName fileName:self.uploadFileName];
}






- (IBAction)downloadAction:(id)sender {
    
    NSString *objectName = @"30AB8AC4-89FD-48BF-A4D8-A88F3FC65AC6.png";
    
    NSString *basePath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSString *dirPath= [basePath stringByAppendingPathComponent:@"YHTXStorageDownload"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = YES;
    if (![fileManager fileExistsAtPath:dirPath isDirectory:&isDir]) {
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *path = [dirPath stringByAppendingPathComponent:objectName];
    NSLog(@"😆图片保存路径:%@", path);
    
    [[YHTXStorage sharedStorage] downloadFileWithObjectName:objectName bucketName:@"test-1257102055" savePath:path progressBlock:^(CGFloat progress) {
        NSLog(@"😆:下载进度:%.2f",progress);
    } completionBlock:^(id  _Nullable outputObject, NSString *_Nullable path, NSError * _Nullable error) {
        if (error) {
            NSLog(@"下载失败:%@",error);
        } else {
            NSLog(@"下载成功:%@",outputObject);
        }
    }];
}
#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    UIImage *selectImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    NSString *fileName = [NSString stringWithFormat:@"%@.png",[NSUUID UUID].UUIDString];
    
    NSString *basePath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSString *dirPath= [basePath stringByAppendingPathComponent:@"YHTXStorageUpload"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = YES;
    if (![fileManager fileExistsAtPath:dirPath isDirectory:&isDir]) {
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *path = [dirPath stringByAppendingPathComponent:fileName];
    
    NSLog(@"😆图片保存路径:%@", path);
    [UIImagePNGRepresentation(selectImage) writeToFile:path atomically:YES];
    
    self.uploadFileName = fileName;
    self.uploadBucketName = @"test-1257102055";
    
    self.isFinedUplaod = NO;
    [[YHTXStorage sharedStorage] uploadFileWithFileName:self.uploadFileName filePath:path bucketName:self.uploadBucketName progressBlock:^(CGFloat progress) {
        NSLog(@"------上传进度:%.2f",progress);
    } completionBlock:^(NSError * _Nullable error, QCloudUploadObjectResult * _Nullable result) {
        self.isFinedUplaod = YES;
        if (error) {
            NSLog(@"😆上传失败:%@",error);
            //[fileManager removeItemAtPath:path error:nil];//不能移除，否则续传会失败
        } else {
            NSLog(@"😆上传成功:%@",result.description);
        }
    }];
    
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:YES completion:nil];
}
@end
