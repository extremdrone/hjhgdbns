//
//  JxbHttpProtocol.m
//  JxbHttpProtocol
//
//  Created by Peter Jin  on 15/11/12.
//  Copyright (c) 2015年 Mail:i@Jxb.name. All rights reserved.
//

#import "JxbHttpProtocol.h"
#import "JxbDebugTool.h"
#import "JxbHttpDatasource.h"
#import "NSData+DebugMan.h"
#import "MethodSwizzling.h"

#define myProtocolKey   @"JxbHttpProtocol"

typedef NSURLSessionConfiguration*(*SessionConfigConstructor)(id,SEL);
static SessionConfigConstructor orig_defaultSessionConfiguration;

static NSURLSessionConfiguration* SWHttp_defaultSessionConfiguration(id self, SEL _cmd)
{
    // call original method
    NSURLSessionConfiguration* config = orig_defaultSessionConfiguration(self,_cmd);
    
    
    
    if (   [config respondsToSelector:@selector(protocolClasses)]
        && [config respondsToSelector:@selector(setProtocolClasses:)]){
        NSMutableArray * urlProtocolClasses = [NSMutableArray arrayWithArray:config.protocolClasses];
        Class protoCls = JxbHttpProtocol.class;
        if (![urlProtocolClasses containsObject:protoCls]){
            [urlProtocolClasses insertObject:protoCls atIndex:0];
        }
        
        config.protocolClasses = urlProtocolClasses;
    }
    
    
    
    return config;
}

@interface JxbHttpProtocol()<NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) NSTimeInterval  startTime;
@end

@implementation JxbHttpProtocol



#pragma mark - protocol
+ (void)load {//liman
    orig_defaultSessionConfiguration = (SessionConfigConstructor)ReplaceMethod(
                                                                               @selector(defaultSessionConfiguration),
                                                                               (IMP)SWHttp_defaultSessionConfiguration,
                                                                               [NSURLSessionConfiguration class],
                                                                               YES);
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (![request.URL.scheme isEqualToString:@"http"] &&
        ![request.URL.scheme isEqualToString:@"https"]) {
        return NO;
    }
    
    if ([NSURLProtocol propertyForKey:myProtocolKey inRequest:request] ) {
        return NO;
    }
    
    if ([[JxbDebugTool shareInstance] onlyURLs].count > 0) {
        NSString* url = [request.URL.absoluteString lowercaseString];
        for (NSString* _url in [JxbDebugTool shareInstance].onlyURLs) {
            if ([url rangeOfString:[_url lowercaseString]].location != NSNotFound)
                return YES;
        }
        return NO;
    }
    
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:myProtocolKey inRequest:mutableReqeust];
    return [mutableReqeust copy];
}

- (void)startLoading {
    self.data = [NSMutableData data];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.connection = [[NSURLConnection alloc] initWithRequest:[[self class] canonicalRequestForRequest:self.request] delegate:self startImmediately:YES];
#pragma clang diagnostic pop
    self.startTime = [[NSDate date] timeIntervalSince1970];
}

- (void)stopLoading {
    [self.connection cancel];
    
    JxbHttpModel* model = [[JxbHttpModel alloc] init];
    model.url = self.request.URL;
    model.method = self.request.HTTPMethod;
    model.mineType = self.response.MIMEType;
    if (self.request.HTTPBody) {
        NSData* data = self.request.HTTPBody;
        if ([[JxbDebugTool shareInstance] isHttpRequestEncrypt]) {
            if ([[JxbDebugTool shareInstance] delegate] && [[JxbDebugTool shareInstance].delegate respondsToSelector:@selector(decryptJson:)]) {
                data = [[JxbDebugTool shareInstance].delegate decryptJson:self.request.HTTPBody];
            }
        }
        model.requestData = data;
    }
    if (self.request.HTTPBodyStream) {//liman
        NSData* data = [NSData dataWithInputStream:self.request.HTTPBodyStream];
        model.requestData = data;
    }
    
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)self.response;
    model.statusCode = [NSString stringWithFormat:@"%d",(int)httpResponse.statusCode];
    model.responseData = self.data;
    model.isImage = [self.response.MIMEType rangeOfString:@"image"].location != NSNotFound;
    model.totalDuration = [NSString stringWithFormat:@"%f (s)",[[NSDate date] timeIntervalSince1970] - self.startTime];
    model.startTime = [NSString stringWithFormat:@"%f",self.startTime];
    
    
    model.errorDescription = self.error.description;
    model.errorLocalizedDescription = self.error.localizedDescription;
    model.headerFields = self.request.allHTTPHeaderFields;
    
    if (self.response.MIMEType == nil) {
        model.isImage = NO;
    }
    
    if ([model.url.absoluteString length] > 4) {
        NSString *str = [model.url.absoluteString substringFromIndex: [model.url.absoluteString length] - 4];
        if ([str isEqualToString:@".png"] || [str isEqualToString:@".PNG"] || [str isEqualToString:@".jpg"] || [str isEqualToString:@".JPG"] || [str isEqualToString:@".gif"] || [str isEqualToString:@".GIF"]) {
            model.isImage = YES;
        }
    }
    if ([model.url.absoluteString length] > 5) {
        NSString *str = [model.url.absoluteString substringFromIndex: [model.url.absoluteString length] - 5];
        if ([str isEqualToString:@".jpeg"] || [str isEqualToString:@".JPEG"]) {
            model.isImage = YES;
        }
    }
    
    //处理500,404等错误
    model = [self handleError:self.error model:model];
    
    if ([[JxbHttpDatasource shareInstance] addHttpRequset:model])
    {
        GCD_DELAY_AFTER(0.1, ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadHttp_DebugMan" object:nil userInfo:@{@"statusCode":model.statusCode}];
        });
    }
}

//处理500,404等错误
- (JxbHttpModel *)handleError:(NSError *)error model:(JxbHttpModel *)model
{
    if (!error) {
        //https://httpstatuses.com/
        switch (model.statusCode.integerValue) {
            case 100:
                model.errorDescription = @"1×× Informational";
                model.errorLocalizedDescription = @"Continue";
                break;
            case 101:
                model.errorDescription = @"1×× Informational";
                model.errorLocalizedDescription = @"Switching Protocols";
                break;
            case 102:
                model.errorDescription = @"1×× Informational";
                model.errorLocalizedDescription = @"Processing";
                break;
            case 200:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"OK";
                break;
            case 201:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"Created";
                break;
            case 202:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"Accepted";
                break;
            case 203:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"Non-authoritative Information";
                break;
            case 204:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"No Content";
                break;
            case 205:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"Reset Content";
                break;
            case 206:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"Partial Content";
                break;
            case 207:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"Multi-Status";
                break;
            case 208:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"Already Reported";
                break;
            case 226:
                model.errorDescription = @"2×× Success";
                model.errorLocalizedDescription = @"IM Used";
                break;
            case 300:
                model.errorDescription = @"3×× Redirection";
                model.errorLocalizedDescription = @"Multiple Choices";
                break;
            case 301:
                model.errorDescription = @"3×× Redirection";
                model.errorLocalizedDescription = @"Moved Permanently";
                break;
            case 302:
                model.errorDescription = @"3×× Redirection";
                model.errorLocalizedDescription = @"Found";
                break;
            case 303:
                model.errorDescription = @"3×× Redirection";
                model.errorLocalizedDescription = @"See Other";
                break;
            case 304:
                model.errorDescription = @"3×× Redirection";
                model.errorLocalizedDescription = @"Not Modified";
                break;
            case 305:
                model.errorDescription = @"3×× Redirection";
                model.errorLocalizedDescription = @"Use Proxy";
                break;
            case 307:
                model.errorDescription = @"3×× Redirection";
                model.errorLocalizedDescription = @"Temporary Redirect";
                break;
            case 308:
                model.errorDescription = @"3×× Redirection";
                model.errorLocalizedDescription = @"Permanent Redirect";
                break;
            case 400:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Bad Request";
                break;
            case 401:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Unauthorized";
                break;
            case 402:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Payment Required";
                break;
            case 403:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Forbidden";
                break;
            case 404:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Not Found";
                break;
            case 405:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Method Not Allowed";
                break;
            case 406:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Not Acceptable";
                break;
            case 407:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Proxy Authentication Required";
                break;
            case 408:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Request Timeout";
                break;
            case 409:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Conflict";
                break;
            case 410:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Gone";
                break;
            case 411:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Length Required";
                break;
            case 412:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Precondition Failed";
                break;
            case 413:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Payload Too Large";
                break;
            case 414:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Request-URI Too Long";
                break;
            case 415:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Unsupported Media Type";
                break;
            case 416:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Requested Range Not Satisfiable";
                break;
            case 417:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Expectation Failed";
                break;
            case 418:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"I'm a teapot";
                break;
            case 421:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Misdirected Request";
                break;
            case 422:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Unprocessable Entity";
                break;
            case 423:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Locked";
                break;
            case 424:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Failed Dependency";
                break;
            case 426:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Upgrade Required";
                break;
            case 428:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Precondition Required";
                break;
            case 429:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Too Many Requests";
                break;
            case 431:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Request Header Fields Too Large";
                break;
            case 444:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Connection Closed Without Response";
                break;
            case 451:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Unavailable For Legal Reasons";
                break;
            case 499:
                model.errorDescription = @"4×× Client Error";
                model.errorLocalizedDescription = @"Client Closed Request";
                break;
            case 500:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Internal Server Error";
                break;
            case 501:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Not Implemented";
                break;
            case 502:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Bad Gateway";
                break;
            case 503:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Service Unavailable";
                break;
            case 504:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Gateway Timeout";
                break;
            case 505:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"HTTP Version Not Supported";
                break;
            case 506:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Variant Also Negotiates";
                break;
            case 507:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Insufficient Storage";
                break;
            case 508:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Loop Detected";
                break;
            case 510:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Not Extended";
                break;
            case 511:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Network Authentication Required";
                break;
            case 599:
                model.errorDescription = @"5×× Server Error";
                model.errorLocalizedDescription = @"Network Connect Timeout Error";
                break;
            default:
                break;
        }
    }
    
    return model;
}

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [[self client] URLProtocol:self didFailWithError:error];
    self.error = error;
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection {
    return YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [[self client] URLProtocol:self didReceiveAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [[self client] URLProtocol:self didCancelAuthenticationChallenge:challenge];
}

#pragma mark - NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    self.response = response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [[self client] URLProtocol:self didLoadData:data];
    [self.data appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return cachedResponse;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [[self client] URLProtocolDidFinishLoading:self];
}
@end

