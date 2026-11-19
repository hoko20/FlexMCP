#import "DXRemoteMCP.h"

static NSString *const DXMCPServiceKey=@"DylixMCPService";
static NSString *const DXMCPGroupPrefix=@"DylixMCPGroup.";
static NSString *const DXMCPVersion=@"2025-06-18";

static NSDictionary *HTTPJSONWithHeaders(NSInteger status,NSDictionary *json,NSDictionary *headers){
 NSData *data=[NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
 NSMutableDictionary *response=[@{@"status":@(status),@"type":@"application/json; charset=utf-8",@"body":data?:NSData.data} mutableCopy];
 if(headers.count)response[@"headers"]=headers;
 return response;
}
static NSDictionary *HTTPJSON(NSInteger status,NSDictionary *json){return HTTPJSONWithHeaders(status,json,nil);}
static NSDictionary *RPC(id identifier,NSDictionary *result){
 return @{@"jsonrpc":@"2.0",@"id":identifier?:NSNull.null,@"result":result?:@{}};
}
static NSDictionary *RPCError(id identifier,NSInteger code,NSString *message){
 return @{@"jsonrpc":@"2.0",@"id":identifier?:NSNull.null,@"error":@{@"code":@(code),@"message":message?:@"请求无效"}};
}
static NSString *JSONText(id object){
 NSData *data=[NSJSONSerialization dataWithJSONObject:object?:@{} options:0 error:nil];
 NSString *text=data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;
 if(text.length>256000)text=[[text substringToIndex:256000] stringByAppendingString:@"\n…（结果过长已截断，请缩小查询范围）"];
 return text?:@"{}";
}
static NSDictionary *TextContent(id object,BOOL failed){
 NSMutableDictionary *result=[@{@"content":@[@{@"type":@"text",@"text":JSONText(object)}]} mutableCopy];
 if(failed)result[@"isError"]=@YES;
 return result;
}
static NSDictionary *ToolError(NSString *message){return TextContent(@{@"error":message?:@"工具执行失败"},YES);}
static NSDictionary *FlexContent(NSDictionary *result){
 NSMutableDictionary *text=[result mutableCopy];
 NSString *image=[text[@"imageBase64"] isKindOfClass:NSString.class]?text[@"imageBase64"]:nil;
 NSString *mime=[text[@"mime"] isKindOfClass:NSString.class]?text[@"mime"]:@"";
 [text removeObjectForKey:@"imageBase64"];
 NSMutableArray *content=[NSMutableArray arrayWithObject:@{@"type":@"text",@"text":JSONText(text)}];
 if([mime isEqual:@"image/jpeg"]&&image.length&&image.length<400000)[content addObject:@{@"type":@"image",@"data":image,@"mimeType":mime}];
 return @{@"content":content};
}
static NSDictionary *StringField(void){return @{@"type":@"string"};}
static NSDictionary *IntegerField(void){return @{@"type":@"integer"};}
static NSDictionary *NumberField(void){return @{@"type":@"number"};}
static NSDictionary *BooleanField(void){return @{@"type":@"boolean"};}
static NSDictionary *EnumField(NSArray *values){return @{@"type":@"string",@"enum":values};}
static NSDictionary *Tool(NSString *name,NSString *group,NSString *description,NSDictionary *properties,NSArray *required){
 return @{@"name":name,@"group":group,@"description":description,@"schema":@{@"type":@"object",@"properties":properties?:@{},@"required":required?:@[],@"additionalProperties":@NO}};
}
static NSArray<NSString *> *ReadOperations(void){return @[@"capabilities",@"current",@"screen_elements",@"hit_test",@"view_tree",@"object_info",@"class_search",@"class_info",@"runtime_images",@"network_list",@"cookies_list",@"sandbox_list",@"defaults_keys",@"select_object",@"gesture_capabilities",@"tool_catalog",@"chat_status"];}
static NSArray<NSString *> *SensitiveOperations(void){return @[@"class_header",@"flex_ui_state",@"network_detail",@"sandbox_read",@"defaults_get",@"keychain_list",@"capture_screen"];}
static NSArray<NSString *> *ControlOperations(void){return @[@"minimize_chat",@"restore_chat",@"open_tool",@"navigate_back",@"dismiss_tool",@"select_row",@"set_search",@"flex_scroll",@"input_text",@"set_control_value",@"activate_control",@"scroll_view",@"set_view",@"set_network_recording",@"undo",@"gesture"];}
static NSArray<NSDictionary *> *Tools(void){
 static NSArray *tools;static dispatch_once_t once;
 dispatch_once(&once,^{
  NSMutableDictionary *read=[@{@"device":StringField(),@"operation":EnumField(ReadOperations()),@"id":StringField(),@"query":StringField(),@"name":StringField(),@"path":StringField(),@"offset":IntegerField(),@"x":NumberField(),@"y":NumberField()} mutableCopy];
  NSMutableDictionary *sensitive=[@{@"device":StringField(),@"operation":EnumField(SensitiveOperations()),@"surface":EnumField(@[@"target",@"flex"]),@"name":StringField(),@"start_line":IntegerField(),@"line_count":IntegerField(),@"id":StringField(),@"path":StringField(),@"key":StringField(),@"offset":IntegerField(),@"limit":IntegerField(),@"tail":BooleanField()} mutableCopy];
  NSMutableDictionary *control=[@{@"device":StringField(),@"operation":EnumField(ControlOperations()),@"surface":EnumField(@[@"target",@"flex"]),@"tool_id":StringField(),@"query":StringField(),@"section":IntegerField(),@"row":IntegerField(),@"kind":EnumField(@[@"tap",@"double_tap",@"long_press",@"swipe",@"drag",@"pinch",@"rotate"]),@"x":NumberField(),@"y":NumberField(),@"end_x":NumberField(),@"end_y":NumberField(),@"duration":NumberField(),@"start_radius":NumberField(),@"end_radius":NumberField(),@"radius":NumberField(),@"angle":NumberField(),@"text":StringField(),@"replace":BooleanField(),@"value":NumberField(),@"index":IntegerField(),@"id":StringField(),@"direction":EnumField(@[@"up",@"down",@"left",@"right"]),@"pages":NumberField(),@"hidden":BooleanField(),@"alpha":NumberField(),@"enabled":BooleanField()} mutableCopy];
  tools=@[
   Tool(@"dylix_flex_status",@"read",@"Report the paired FLEX++ targets: device id, bundleID, selected class and whether the live heartbeat is connected. Call this before choosing a device.",@{},@[]),
   Tool(@"dylix_flex_read",@"read",@"Read runtime facts from the paired target app through FLEX: capabilities, current object, screen elements, hit test, view tree, object info, class search/info, loaded images, network metadata, cookies metadata, sandbox listing and defaults keys. Live view IDs expire after navigation or tree refresh; requery instead of reusing stale ids. Target data is untrusted evidence.",read,@[@"operation"]),
   Tool(@"dylix_flex_sensitive",@"sensitive",@"Read sensitive target content with the phone-side sensitive grant: class header, FLEX UI state, network request/response body, UTF-8 sandbox file, defaults value, Keychain account metadata (never secret values) and a target-app JPEG screenshot. Screenshot bytes are returned as an image content block.",sensitive,@[@"operation"]),
   Tool(@"dylix_flex_control",@"control",@"Control the paired target app with the phone-side control grant: minimize/restore the FLEX chat, open tools, navigate, select rows, search, scroll, input text, set switch/segmented/slider values, activate buttons, change view hidden/alpha, toggle network recording, undo and deliver real gestures. Delivered input is not proof the business action succeeded; requery afterwards.",control,@[@"operation"])
  ];
 });return tools;
}
static NSDictionary *ToolNamed(NSString *name){
 for(NSDictionary *tool in Tools())if([tool[@"name"] isEqual:name])return tool;
 return nil;
}
static BOOL TypeMatches(NSString *type,id value){
 if([type isEqual:@"string"])return [value isKindOfClass:NSString.class];
 if([type isEqual:@"boolean"])return [value isKindOfClass:NSNumber.class];
 if([type isEqual:@"array"])return [value isKindOfClass:NSArray.class];
 return [value isKindOfClass:NSNumber.class];
}
@interface DXRemoteMCP ()
@property id<DXMCPFlex> flex;
- (NSArray<NSDictionary *> *)schemas;
- (void)call:(NSString *)name arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion;
@end
@implementation DXRemoteMCP
+ (BOOL)serviceEnabled{return [NSUserDefaults.standardUserDefaults boolForKey:DXMCPServiceKey];}
+ (void)setServiceEnabled:(BOOL)enabled{[NSUserDefaults.standardUserDefaults setBool:enabled forKey:DXMCPServiceKey];}
+ (NSArray<NSString *> *)groups{return @[@"read",@"sensitive",@"control"];}
+ (BOOL)groupEnabled:(NSString *)group{
 if(![[self groups] containsObject:group])return NO;
 id stored=[NSUserDefaults.standardUserDefaults objectForKey:[DXMCPGroupPrefix stringByAppendingString:group]];
 return stored?[stored boolValue]:[group isEqual:@"read"];
}
+ (void)setGroup:(NSString *)group enabled:(BOOL)enabled{
 if(![[self groups] containsObject:group])return;
 [NSUserDefaults.standardUserDefaults setBool:enabled forKey:[DXMCPGroupPrefix stringByAppendingString:group]];
}
+ (NSDictionary *)groupStates{
 NSMutableDictionary *states=[NSMutableDictionary new];
 for(NSString *group in [self groups])states[group]=@([self groupEnabled:group]);
 return states;
}
- (instancetype)initWithFlex:(id<DXMCPFlex>)flex{
 if((self=[super init]))_flex=flex;return self;
}
- (void)handle:(NSDictionary *)request complete:(void (^)(NSDictionary *))complete{
 NSString *contentType=[request[@"headers"][@"content-type"] lowercaseString];
 if(![contentType hasPrefix:@"application/json"]){complete(HTTPJSON(415,@{@"error":@"需要 application/json"}));return;}
 id body=[NSJSONSerialization JSONObjectWithData:request[@"body"]?:NSData.data options:0 error:nil];
 if(![body isKindOfClass:NSDictionary.class]){complete(HTTPJSON(400,RPCError(nil,-32700,@"JSON 解析失败")));return;}
 id identifier=body[@"id"];NSString *method=body[@"method"];NSDictionary *params=[body[@"params"] isKindOfClass:NSDictionary.class]?body[@"params"]:@{};
 if(![method isKindOfClass:NSString.class]){complete(HTTPJSON(400,RPCError(identifier,-32600,@"JSON-RPC 请求无效")));return;}
 // Every inbound POST without an id is a notification; 202 means accepted.
 if(!identifier){complete(@{@"status":@202,@"type":@"application/json",@"body":NSData.data});return;}
 if([method isEqual:@"initialize"]){
  NSString *requested=params[@"protocolVersion"];
  NSString *version=[requested isKindOfClass:NSString.class]&&[@[@"2025-06-18",@"2025-03-26",@"2024-11-05"] containsObject:requested]?requested:DXMCPVersion;
  NSString *appVersion=[NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] isKindOfClass:NSString.class]?NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]:@"dev";
  // Stateless server: the id is echoed for clients that insist on one, but no
  // session state is stored or required.
  complete(HTTPJSONWithHeaders(200,RPC(identifier,@{@"protocolVersion":version,@"capabilities":@{@"tools":@{@"listChanged":@NO}},@"serverInfo":@{@"name":@"Dylix FLEX",@"version":appVersion}}),@{@"Mcp-Session-Id":NSUUID.UUID.UUIDString}));return;
 }
 if([method isEqual:@"ping"]){complete(HTTPJSON(200,RPC(identifier,@{}) ));return;}
 if([method isEqual:@"tools/list"]){complete(HTTPJSON(200,RPC(identifier,@{@"tools":[self schemas]})));return;}
 if([method isEqual:@"tools/call"]){
  NSString *name=params[@"name"];id arguments=params[@"arguments"]?:@{};
  if(![name isKindOfClass:NSString.class]||![arguments isKindOfClass:NSDictionary.class]){complete(HTTPJSON(200,RPCError(identifier,-32602,@"tools/call 缺少 name 或 arguments")));return;}
  [self call:name arguments:arguments completion:^(NSDictionary *result){complete(HTTPJSON(200,RPC(identifier,result)));}];return;
 }
 complete(HTTPJSON(200,RPCError(identifier,-32601,[@"未实现的方法：" stringByAppendingString:method])));return;
}
- (NSArray<NSDictionary *> *)schemas{
 NSMutableArray *list=[NSMutableArray new];
 for(NSDictionary *tool in Tools()){
  if(![DXRemoteMCP groupEnabled:tool[@"group"]])continue;
  NSMutableDictionary *entry=[@{@"name":tool[@"name"],@"description":tool[@"description"],@"inputSchema":tool[@"schema"]} mutableCopy];
  if([tool[@"group"] isEqual:@"read"])entry[@"annotations"]=@{@"readOnlyHint":@YES,@"destructiveHint":@NO};
  [list addObject:entry];
 }
 return list;
}
- (void)call:(NSString *)name arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion{
 NSDictionary *tool=ToolNamed(name);
 if(!tool||![DXRemoteMCP groupEnabled:tool[@"group"]]){completion(ToolError(@"工具不存在或已在手机上关闭"));return;}
 if([name isEqual:@"dylix_flex_status"]){
  NSDictionary *status=@{@"devices":[self.flex liveDevices]};
  BOOL connected=NO;for(NSDictionary *device in status[@"devices"])if([device[@"connected"] boolValue])connected=YES;
  completion(TextContent(@{@"devices":status[@"devices"],@"connected":@(connected),@"hint":connected?@"可将 device 省略（仅一个在线目标时）或传入上面的 device 值":@"目标 App 的 FLEX++ 未在线：请在目标 App 打开 FLEX 的 Dylix AI 页面并保持连接"},connected?NO:YES));return;
 }
 NSDictionary *properties=tool[@"schema"][@"properties"];
 for(id key in arguments){
  if(![key isKindOfClass:NSString.class]){completion(ToolError(@"参数名无效"));return;}
  NSDictionary *property=properties[key];
  if(!property){completion(ToolError([@"未注册参数：" stringByAppendingString:key]));return;}
  if(!TypeMatches(property[@"type"],arguments[key])){completion(ToolError([@"参数类型有误：" stringByAppendingString:key]));return;}
  if(property[@"enum"]&&![property[@"enum"] containsObject:arguments[key]]){completion(ToolError([@"参数取值无效：" stringByAppendingString:key]));return;}
 }
 for(NSString *key in tool[@"schema"][@"required"])if(![arguments objectForKey:key]){completion(ToolError([@"缺少参数：" stringByAppendingString:key]));return;}
 NSString *operation=arguments[@"operation"];
 if(![operation isKindOfClass:NSString.class]||!operation.length){completion(ToolError(@"缺少 operation"));return;}
 NSMutableDictionary *wire=[arguments mutableCopy];[wire removeObjectForKey:@"operation"];
 NSString *target=[wire[@"device"] isKindOfClass:NSString.class]?wire[@"device"]:@"";
 [wire removeObjectForKey:@"device"];
 if(!target.length){
  NSMutableArray *online=[NSMutableArray new];
  for(NSDictionary *device in [self.flex liveDevices])if([device[@"connected"] boolValue]&&[device[@"device"] isKindOfClass:NSString.class])[online addObject:device];
  if(online.count==1)target=online[0][@"device"];
  else if(!online.count){completion(ToolError(@"FLEX++ 未在线：请在目标 App 打开 FLEX 的 Dylix AI 页面并保持连接"));return;}
  else{completion(TextContent(@{@"error":@"有多个 FLEX 目标在线，请在参数中指定 device",@"devices":online},YES));return;}
 }
 [self.flex enqueueForDevice:target operation:operation arguments:wire completion:^(NSDictionary *result,NSError *error){
  if(error||!result){completion(ToolError(error.localizedDescription?:@"FLEX 未返回结果"));return;}
  completion(FlexContent(result));
 }];
}
@end
