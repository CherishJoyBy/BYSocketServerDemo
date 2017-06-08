//
//  ViewController.m
//  AngelServer
//
//  Created by lby on 16/12/29.
//  Copyright © 2016年 lby. All rights reserved.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"

@interface ViewController ()<GCDAsyncSocketDelegate>

// 服务器端口
@property (weak, nonatomic) IBOutlet UITextField *portTextF;
// 信息展示
@property (weak, nonatomic) IBOutlet UITextField *messageTextF;
@property (weak, nonatomic) IBOutlet UITextView *showMessageTextV;
// 检测心跳计时器
@property (nonatomic, strong) NSTimer *checkTimer;
// 服务器socket(开放端口,监听客户端socket的连接)
@property (strong, nonatomic) GCDAsyncSocket *serverSocket;
// 保存客户端socket
@property (nonatomic, copy) NSMutableArray *clientSockets;
// 客户端标识和心跳接收时间的字典
@property (nonatomic, copy) NSMutableDictionary *clientPhoneTimeDicts;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 初始化服务器socket
    self.serverSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
//    NSLog(@"%@",self.serverSocket);
    
}

- (IBAction)startNotice:(id)sender
{
    // 开放哪一个端口
    NSError *error = nil;
    BOOL result = [self.serverSocket acceptOnPort:[self.portTextF.text integerValue] error:&error];
    if (result && error == nil) {
        // 开放成功
        [self showMessageWithStr:@"开放成功"];
    }
    else
    {
        [self showMessageWithStr:@"已经开放"];
    }
}

// 添加计时器
- (void)addTimer
{
    // 长连接定时器
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(checkLongConnect) userInfo:nil repeats:YES];
    // 把定时器添加到当前运行循环,并且调为通用模式
    [[NSRunLoop currentRunLoop] addTimer:self.checkTimer forMode:NSRunLoopCommonModes];
}

// 检测心跳
- (void)checkLongConnect
{
    [self.clientPhoneTimeDicts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        // 获取当前时间
        NSString *currentTimeStr = [self getCurrentTime];
        // 延迟超过10秒判断断开
        if (([currentTimeStr doubleValue] - [obj doubleValue]) > 10.0)
        {
            [self showMessageWithStr:[NSString stringWithFormat:@"%@已经断开,连接时差%f",key,[currentTimeStr doubleValue] - [obj doubleValue]]];
            [self showMessageWithStr:[NSString stringWithFormat:@"移除%@",key]];
            [self.clientPhoneTimeDicts removeObjectForKey:key];
        }
        else
        {
            [self showMessageWithStr:[NSString stringWithFormat:@"%@处于连接状态,连接时差%f",key,[currentTimeStr doubleValue] - [obj doubleValue]]];
        }
    }];
}

// socket是保存的客户端socket, 表示给客户端socket发送消息
- (IBAction)sendMessage:(id)sender
{
    if(self.clientSockets == nil) return;
    NSData *data = [self.messageTextF.text dataUsingEncoding:NSUTF8StringEncoding];
    // withTimeout -1 : 无穷大,一直等
    // tag : 消息标记
    [self.clientSockets enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj writeData:data withTimeout:-1 tag:0];
    }];
}

// 信息展示
- (void)showMessageWithStr:(NSString *)str
{
    self.showMessageTextV.text = [self.showMessageTextV.text stringByAppendingFormat:@"%@\n", str];
}

#pragma mark - 服务器socketDelegate
// 连接上新的客户端socket
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(nonnull GCDAsyncSocket *)newSocket
{
    // 保存客户端的socket
    [self.clientSockets addObject: newSocket];
    // 添加定时器
    [self addTimer];
    
    [self showMessageWithStr:@"链接成功"];
    [self showMessageWithStr:[NSString stringWithFormat:@"客户端的地址: %@ -------端口: %d", newSocket.connectedHost, newSocket.connectedPort]];
    
    [newSocket readDataWithTimeout:- 1 tag:0];
}

/**
 读取客户端的数据

 @param sock 客户端的Socket
 @param data 客户端发送的数据
 @param tag 当前读取的标记
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *text = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    [self showMessageWithStr:text];
    
    // 第一次读取到的数据直接添加
    if (self.clientPhoneTimeDicts.count == 0)
    {
        [self.clientPhoneTimeDicts setObject:[self getCurrentTime] forKey:text];
    }
    else
    {
        [self.clientPhoneTimeDicts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [self.clientPhoneTimeDicts setObject:[self getCurrentTime] forKey:text];
        }];
    }
    
    [sock readDataWithTimeout:- 1 tag:0];
}
// 断开客户端
//- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
//{
//    [self.clientSockets removeObject:sock];
//    [self showMessageWithStr:[NSString stringWithFormat:@"断开移除%@",sock]];
//}

#pragma mark - Lazy Load
- (NSMutableArray *)clientSockets
{
    if (_clientSockets == nil) {
        _clientSockets = [NSMutableArray array];
    }
    return _clientSockets;
}

- (NSMutableDictionary *)clientPhoneTimeDicts
{
    if (_clientPhoneTimeDicts == nil)
    {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        _clientPhoneTimeDicts = dict;
    }
    return _clientPhoneTimeDicts;
}

#pragma mark - Private Method
- (NSString *)getCurrentTime
{
    NSDate* date = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval currentTime = [date timeIntervalSince1970];
    NSString *currentTimeStr = [NSString stringWithFormat:@"%.0f", currentTime];
    return currentTimeStr;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}

@end
