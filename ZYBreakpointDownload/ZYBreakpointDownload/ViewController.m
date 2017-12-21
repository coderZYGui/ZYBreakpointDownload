//
//  ViewController.m
//  ZYBreakpointDownload
//
//  Created by 朝阳 on 2017/12/21.
//  Copyright © 2017年 sunny. All rights reserved.
//

#import "ViewController.h"
#define FileName @"zy.mp4"

@interface ViewController ()<NSURLSessionDataDelegate>

@property (nonatomic, strong) NSFileHandle *handle;

@property (nonatomic, assign) NSInteger totalSize;

@property (nonatomic, assign) NSInteger currentSize;

@property (nonatomic, strong) NSString *fullPath;

@property (weak, nonatomic) IBOutlet UISlider *slider;

@property (nonatomic,strong) NSURLSessionDataTask *dataTask;

@property (nonatomic,strong) NSURLSession *session;


@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //设置slider的进度状态 = 1.0 * 已经下载的文件大小 / 总文件大小
    self.slider.value = [self getSandboxFileSize];
    
    if (self.slider.value == 1.0) {
        self.slider.value = 0;
    }
    
}

- (CGFloat)getSandboxFileSize
{
    //1. 读取沙盒中保存的总文件大小
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *totalFileSize = [defaults objectForKey:@"fileSize"];
    NSNumber *currentFileSize = [defaults objectForKey:@"currentFileSize"];
    
    NSInteger totalSize = [totalFileSize integerValue];
    NSInteger currentSize = [currentFileSize integerValue];
    
    NSLog(@"%ld",totalSize);
    NSLog(@"%ld",currentSize);
    
    return 1.0 * currentSize / totalSize;
}

#pragma -mark lazy loading
- (NSURLSession *)session
{
    if (!_session) {
        //创建会话对象,并设置代理
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return _session;
}

- (NSString *)fullPath
{
    if (!_fullPath) {
        
        //2. 获取文件全路径
        _fullPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingString:FileName];
    }
    return _fullPath;
}

- (NSURLSessionDataTask *)dataTask
{
    if (!_dataTask) {
        //1. url
        NSURL *url = [NSURL URLWithString:@"http://flv2.bn.netease.com/videolib3/1604/28/fVobI0704/SD/fVobI0704-mobile.mp4"];
        
        //2. 创建请求对象
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        // 获取指定文件路径对应的文件大小(当前已经下载的文件大小)
        self.currentSize = [self getFileSize];
        NSLog(@"currentSize----+++++++++++++++++++----%ld",self.currentSize);
        //2.1 设置请求头信息,告诉服务器请求的哪一部分数据(请求当前下载过的数据 之后的数据)
        // 只要设置HTTP请求头的Range属性, 就可以实现从指定位置开始下载
        /*
         表示头500个字节：Range: bytes=0-499
         表示第二个500字节：Range: bytes=500-999
         表示最后500个字节：Range: bytes=-500
         表示500字节以后的范围：Range: bytes=500-
         */
        NSString *range = [NSString stringWithFormat:@"bytes=%zd-",self.currentSize];
        [request setValue:range forHTTPHeaderField:@"Range"];
        
        //3. 创建Task任务
        _dataTask = [self.session dataTaskWithRequest:request];
    }
    return _dataTask;
}

// 获取指定文件路径对应的文件大小
- (NSInteger)getFileSize
{
    NSDictionary *fileInfoDict = [[NSFileManager defaultManager] attributesOfItemAtPath:self.fullPath error:nil];
    NSLog(@"%@",fileInfoDict);
    // 获得字典中文件的信息-文件大小
    // currentSize = self.currentSize;
    NSInteger currentSize = [fileInfoDict[@"NSFileSize"] integerValue];
    
    return currentSize;
}

- (IBAction)startDwonload:(id)sender
{
    NSLog(@"+++++++++++++++开始下载");
    //5. 执行Task
    [self.dataTask resume];
}

- (IBAction)supendDownload:(id)sender
{
    NSLog(@"+++++++++++++++暂停下载");
    [self.dataTask suspend];
}

// cancel方法: 不可恢复下载
- (IBAction)cancelDownload:(id)sender
{
    NSLog(@"+++++++++++++++取消下载");
    [self.dataTask cancel];
    // 清空dataTask.在resumeDownload:方法中,self.dataTask 走懒加载方法
    self.dataTask = nil;
}

// 恢复下载
- (IBAction)resumeDownload:(id)sender
{
    NSLog(@"+++++++++++++++恢复下载");
    [self.dataTask resume];
}

#pragma -mark NSURLSessionDataDelegate
/**
 接收到服务器的响应 它默认会取消该请求
 
 @param session 会话对象
 @param dataTask 请求任务
 @param response 响应头信息
 @param completionHandler 回调 传给系统
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    
    //0. 得到 文件的总大小(本次请求的文件数据的总大小)
    // 本次请求的文件数据大小 != 文件总大小(如果再次发送请求的时候,此时的self.totalSize 就小于文件的大小,因此在\
    在后面计算 1.0 * self.currentSize / self.totalSize 的时候,会出现数据错乱) 因此要加上当前已经下载的数据.
    self.totalSize = response.expectedContentLength + self.currentSize;
    
    // 将文件总大小写入到沙盒中
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(self.totalSize) forKey:@"fileSize"];
    
    /*
     NSURLSessionResponseCancel = 0,取消 默认
     NSURLSessionResponseAllow = 1, 接收
     NSURLSessionResponseBecomeDownload = 2, 变成下载任务
     NSURLSessionResponseBecomeStream        变成流
     */
    
    //1. 因为系统默认是 取消任务请求. 所以要设置 枚举 为接收
    completionHandler(NSURLSessionResponseAllow);
    
    
    // 如果当前下载的数据为0. 就创建一个空文件(防止,多创建空文件导致文件大小紊乱)
    if (self.currentSize == 0) {
        //3. 创建一个空文件(将文件写入到沙盒中)
        [[NSFileManager defaultManager] createFileAtPath:self.fullPath contents:nil attributes:nil];
    }
    
    //4. 创建文件句柄
    self.handle = [NSFileHandle fileHandleForWritingAtPath:self.fullPath];
    //5. 每次在下载过数据后,继续拼接
    [self.handle seekToEndOfFile];
}

/**
 接收到服务器返回的数据  调用多次
 
 @param session 会话对象
 @param dataTask 请求任务
 @param data 本次下载的数据
 */
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    //1. 写入数据到文件
    [self.handle writeData:data];
    //2. 拼接已经下载过的数据
    self.currentSize += data.length;
    // 将已经下载的文件大小写入到沙盒中
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(self.currentSize) forKey:@"currentFileSize"];
    
    //3. 下载进度
    NSLog(@"%f",1.0 * self.currentSize / self.totalSize);
    
    self.slider.value = 1.0 * self.currentSize / self.totalSize;
}

/**
 请求结束或失败的时候调用
 
 @param session 会话对象
 @param task 请求任务
 @param error 错误信息
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    //1. 关闭文件句柄
    [self.handle closeFile];
    self.handle = nil;
    
    NSLog(@"%@",self.fullPath);
    
}

- (void)dealloc
{
    // 如果session设置代理的话,会有一个强引用.不会被释放.因此最后要释放session对象:调用下面两个方法都行.\
    否则会有内存泄漏.
    // finishTasksAndInvalidate
    [self.session invalidateAndCancel];
}

@end
