#import <Foundation/Foundation.h>
#import "../App/Remote/DXRemoteMCP.h"
#import "../App/Remote/DXRemoteAccess.h"
@interface StubFlex : NSObject <DXMCPFlex>
@property NSMutableArray<NSDictionary *> *calls;
@property NSArray<NSDictionary *> *devices;
@property BOOL fails;
@end
@implementation StubFlex
- (instancetype)init{
 if((self=[super init])){
  _calls=[NSMutableArray new];
  _devices=@[@{@"device":@"D1",@"bundleID":@"com.example.app",@"className":@"DemoController",@"connected":@YES,@"hasReport":@YES,@"expiresAt":@1}];
 }return self;
}
- (NSArray<NSDictionary *> *)liveDevices{return self.devices;}
- (void)enqueueForDevice:(NSString *)device operation:(NSString *)operation arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *,NSError *))completion{
 [self.calls addObject:@{@"device":device?:@"",@"operation":operation?:@"",@"arguments":arguments?:@{}}];
 if(self.fails){completion(nil,[NSError errorWithDomain:@"FLEX" code:1 userInfo:@{NSLocalizedDescriptionKey:@"FLEX 命令已过期"}]);return;}
 if([operation isEqual:@"capture_screen"]){completion(@{@"imageBase64":@"ZmFrZS1qcGVn",@"mime":@"image/jpeg",@"capturedAt":@1},nil);return;}
 completion(@{@"ok":@YES,@"operation":operation,@"arguments":arguments?:@{}},nil);
}
@end
static NSUInteger Checks;
static void Check(BOOL ok,NSString *name){if(!ok){NSLog(@"FAIL %@",name);exit(1);}Checks++;NSLog(@"PASS %@",name);}
static NSDictionary *Call(DXRemoteMCP *mcp,dispatch_queue_t queue,NSDictionary *rpc,BOOL notification){
 __block NSDictionary *response=nil;dispatch_semaphore_t sem=dispatch_semaphore_create(0);
 NSData *body=[NSJSONSerialization dataWithJSONObject:rpc options:0 error:nil];
 NSDictionary *request=@{@"path":@"/mcp",@"method":@"POST",@"headers":@{@"content-type":@"application/json"},@"body":body};
 dispatch_sync(queue,^{[mcp handle:request complete:^(NSDictionary *result){response=result;dispatch_semaphore_signal(sem);}];});
 if(!notification)dispatch_semaphore_wait(sem,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC));
 return response;
}
static NSDictionary *Body(NSDictionary *response){return [NSJSONSerialization JSONObjectWithData:response[@"body"]?:NSData.data options:0 error:nil];}
static NSDictionary *ToolCall(DXRemoteMCP *mcp,dispatch_queue_t queue,NSString *name,NSDictionary *arguments){
 return Body(Call(mcp,queue,@{@"jsonrpc":@"2.0",@"id":@1,@"method":@"tools/call",@"params":@{@"name":name,@"arguments":arguments}},NO))[@"result"];
}
static NSArray<NSString *> *Names(NSArray *tools){
 NSMutableArray *names=[NSMutableArray new];for(NSDictionary *tool in tools)[names addObject:tool[@"name"]];return names;
}
int main(int argc,char **argv){@autoreleasepool{
 for(NSString *group in [DXRemoteMCP groups])[DXRemoteMCP setGroup:group enabled:[group isEqual:@"read"]];
 [DXRemoteMCP setServiceEnabled:YES];
 dispatch_queue_t queue=dispatch_queue_create("dylix.mcp.test",DISPATCH_QUEUE_SERIAL);
 StubFlex *flex=[StubFlex new];DXRemoteMCP *mcp=[[DXRemoteMCP alloc]initWithFlex:flex];
 NSDictionary *initialized=Body(Call(mcp,queue,@{@"jsonrpc":@"2.0",@"id":@1,@"method":@"initialize",@"params":@{@"protocolVersion":@"2025-06-18"}},NO));
 Check([initialized[@"result"][@"protocolVersion"] isEqual:@"2025-06-18"],@"initialize negotiates the requested protocol version");
 Check([initialized[@"result"][@"serverInfo"][@"name"] isEqual:@"Dylix FLEX"],@"initialize reports the Dylix FLEX identity");
 NSArray *readOnly=Names(Body(Call(mcp,queue,@{@"jsonrpc":@"2.0",@"id":@2,@"method":@"tools/list"},NO))[@"result"][@"tools"]);
 Check([readOnly containsObject:@"dylix_flex_status"]&&[readOnly containsObject:@"dylix_flex_read"],@"read group exposes status and live reads");
 Check(![readOnly containsObject:@"dylix_flex_sensitive"]&&![readOnly containsObject:@"dylix_flex_control"],@"sensitive and control stay hidden until granted");
 [DXRemoteMCP setGroup:@"sensitive" enabled:YES];[DXRemoteMCP setGroup:@"control" enabled:YES];
 NSArray *all=Names(Body(Call(mcp,queue,@{@"jsonrpc":@"2.0",@"id":@3,@"method":@"tools/list"},NO))[@"result"][@"tools"]);
 Check(all.count==4,@"enabling both grants exposes all four tools");
 NSDictionary *status=ToolCall(mcp,queue,@"dylix_flex_status",@{});
 Check(![status[@"isError"] boolValue]&&[status[@"content"][0][@"text"] containsString:@"com.example.app"],@"status lists the paired FLEX target");
 NSDictionary *unknown=ToolCall(mcp,queue,@"dylix_flex_read",@{@"operation":@"view_tree",@"command":@"rm"});
 Check([unknown[@"isError"] boolValue],@"unregistered arguments are rejected");
 NSDictionary *badOperation=ToolCall(mcp,queue,@"dylix_flex_read",@{@"operation":@"delete_everything"});
 Check([badOperation[@"isError"] boolValue]&&flex.calls.count==0,@"operations outside the schema enum never reach FLEX");
 NSDictionary *tree=ToolCall(mcp,queue,@"dylix_flex_read",@{@"operation":@"view_tree"});
 NSDictionary *forwarded=flex.calls.lastObject;
 Check(![tree[@"isError"] boolValue]&&[forwarded[@"operation"] isEqual:@"view_tree"]&&[forwarded[@"device"] isEqual:@"D1"],@"live read auto-selects the only connected target");
 Check(forwarded[@"arguments"][@"operation"]==nil,@"operation is stripped from the wire payload");
 NSDictionary *gesture=ToolCall(mcp,queue,@"dylix_flex_control",@{@"operation":@"gesture",@"kind":@"tap",@"x":@12.5,@"y":@30});
 Check(![gesture[@"isError"] boolValue]&&[flex.calls.lastObject[@"operation"] isEqual:@"gesture"]&&[flex.calls.lastObject[@"arguments"][@"kind"] isEqual:@"tap"],@"control forwards real gesture coordinates");
 NSDictionary *shot=ToolCall(mcp,queue,@"dylix_flex_sensitive",@{@"operation":@"capture_screen"});
 NSArray *content=shot[@"content"];
 Check(content.count==2&&[content[1][@"type"] isEqual:@"image"]&&[content[1][@"mimeType"] isEqual:@"image/jpeg"],@"screenshot becomes an MCP image content block");
 Check(![content[0][@"text"] containsString:@"ZmFrZS1qcGVn"],@"base64 is removed from the text block");
 flex.fails=YES;
 NSDictionary *expired=ToolCall(mcp,queue,@"dylix_flex_read",@{@"operation":@"current"});
 Check([expired[@"isError"] boolValue]&&[expired[@"content"][0][@"text"] containsString:@"过期"],@"bridge timeout is reported as a tool error");
 flex.fails=NO;
 flex.devices=@[@{@"device":@"D1",@"connected":@YES},@{@"device":@"D2",@"connected":@YES}];
 NSDictionary *ambiguous=ToolCall(mcp,queue,@"dylix_flex_read",@{@"operation":@"current"});
 Check([ambiguous[@"isError"] boolValue]&&[ambiguous[@"content"][0][@"text"] containsString:@"D2"],@"multiple live targets require an explicit device");
 NSDictionary *chosen=ToolCall(mcp,queue,@"dylix_flex_read",@{@"operation":@"current",@"device":@"D2"});
 Check(![chosen[@"isError"] boolValue]&&[flex.calls.lastObject[@"device"] isEqual:@"D2"],@"an explicit device is forwarded");
 flex.devices=@[@{@"device":@"D1",@"connected":@NO}];
 NSDictionary *offline=ToolCall(mcp,queue,@"dylix_flex_read",@{@"operation":@"current"});
 Check([offline[@"isError"] boolValue],@"offline targets are rejected");
 flex.devices=@[@{@"device":@"D1",@"bundleID":@"com.example.app",@"connected":@YES}];
 [DXRemoteMCP setGroup:@"control" enabled:NO];
 NSDictionary *blocked=ToolCall(mcp,queue,@"dylix_flex_control",@{@"operation":@"undo"});
 Check([blocked[@"isError"] boolValue],@"disabling the group blocks the tool again");
 NSDictionary *note=Call(mcp,queue,@{@"jsonrpc":@"2.0",@"method":@"notifications/initialized"},YES);
 Check([note[@"status"] integerValue]==202&&[note[@"body"] length]==0,@"notifications receive 202 without a body");
 NSDictionary *unsupported=Body(Call(mcp,queue,@{@"jsonrpc":@"2.0",@"id":@9,@"method":@"resources/list"},NO));
 Check([unsupported[@"error"][@"code"] integerValue]==-32601,@"unsupported methods return -32601");
 NSString *store=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@"/devices.json"]];
 DXRemoteAccess *access=[[DXRemoteAccess alloc]initWithStore:store];
 Check([access setFixedCode:@"123456" error:nil],@"fixed pairing code is accepted");
 Check([access authorizeMCP:@"123456" peer:@"10.0.0.2"],@"fixed code authorizes MCP Bearer requests");
 Check(![access authorizeMCP:@"654321" peer:@"10.0.0.3"],@"a wrong code is rejected");
 for(NSUInteger i=0;i<10;i++)[access authorizeMCP:@"000000" peer:@"10.0.0.4"];
 Check(![access authorizeMCP:@"123456" peer:@"10.0.0.4"],@"repeated failures rate limit that peer");
 [access rotateCode];
 Check([access authorizeMCP:access.pairingCode peer:@"10.0.0.5"],@"a valid random code authorizes during its lifetime");
 NSLog(@"PASS %lu MCP server checks",(unsigned long)Checks);
 }return 0;}
