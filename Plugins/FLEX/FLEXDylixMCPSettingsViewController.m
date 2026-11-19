#import "FLEXDylixMCPSettingsViewController.h"
#import "FLEXDylixMCPServer.h"

@implementation FLEXDylixMCPSettingsViewController
- (instancetype)init{
 if((self=[super initWithStyle:UITableViewStyleInsetGrouped])){
  self.title=@"MCP 服务";
  self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
 }
 return self;
}
- (void)viewDidLoad{
 [super viewDidLoad];
 self.tableView.rowHeight=50;
 [self reloadSoon];
}
- (void)done{[self dismissViewControllerAnimated:YES completion:nil];}
- (void)reloadSoon{
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.6*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self.tableView reloadData];});
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{return 3;}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
 return section==0?@"服务":section==1?@"授权":@"使用方式";
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
 if(section==1)return @"授权保护开启时必须携带 Bearer 令牌；关闭后同一局域网内无需令牌即可连接，请仅在可信网络使用。自定义授权码支持 8–64 位字母、数字、点、下划线和短横线。";
 if(section==2)return @"在电脑端 MCP 客户端（Claude Desktop、Cursor、Cherry Studio 等）添加 Streamable HTTP 服务，URL 填上方访问地址；开启授权保护时请求头加 Authorization: Bearer <访问令牌>。服务只在宿主 App 进程内运行，App 被挂起或杀死时连接会中断，重新打开 App 后自动恢复。HTTP 为明文，仅用于可信局域网。";
 return nil;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
 return section==0?4:section==1?6:2;
}
- (UITableViewCell *)cell:(UITableView *)tableView{
 UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"cell"];
 if(!cell)cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
 return cell;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
 UITableViewCell *cell=[self cell:tableView];
 cell.accessoryView=nil;cell.accessoryType=UITableViewCellAccessoryNone;cell.selectionStyle=UITableViewCellSelectionStyleDefault;
 cell.detailTextLabel.text=nil;cell.textLabel.textColor=UIColor.labelColor;cell.textLabel.font=[UIFont systemFontOfSize:17];
 if(indexPath.section==0){
  cell.textLabel.text=@[@"MCP 服务",@"监听端口",@"访问地址",@"运行状态"][indexPath.row];
  if(indexPath.row==0){UISwitch *toggle=[UISwitch new];toggle.on=[FLEXDylixMCPServer isEnabled];[toggle addTarget:self action:@selector(toggleService:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;}
  else if(indexPath.row==1){cell.detailTextLabel.text=[NSString stringWithFormat:@"%lu",(unsigned long)[FLEXDylixMCPServer port]];cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
  else if(indexPath.row==2){cell.detailTextLabel.text=[FLEXDylixMCPServer endpoint];cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
  else cell.detailTextLabel.text=[FLEXDylixMCPServer status];
 }
 else if(indexPath.section==1){
  cell.textLabel.text=@[@"授权保护",@"访问令牌",@"自定义授权码",@"重新生成令牌",@"敏感读取",@"界面控制"][indexPath.row];
  if(indexPath.row==0){UISwitch *toggle=[UISwitch new];toggle.on=[FLEXDylixMCPServer authRequired];toggle.tag=820;[toggle addTarget:self action:@selector(toggleGroup:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;}
  else if(indexPath.row<=3){
   if(![FLEXDylixMCPServer authRequired])cell.textLabel.textColor=UIColor.secondaryLabelColor;
   if(indexPath.row==1){cell.detailTextLabel.text=@"轻点复制";cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
   else if(indexPath.row==2)cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
   else if([FLEXDylixMCPServer authRequired])cell.textLabel.textColor=UIColor.systemRedColor;
  }
  else{UISwitch *toggle=[UISwitch new];toggle.on=indexPath.row==4?[FLEXDylixMCPServer sensitiveEnabled]:[FLEXDylixMCPServer controlEnabled];toggle.tag=821+indexPath.row-4;[toggle addTarget:self action:@selector(toggleGroup:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;}
 }
 else{
  if(indexPath.row==0){cell.textLabel.text=@"复制 MCP 客户端配置";cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
  else{
   cell.textLabel.text=@"工具：dylix_flex_status / read / sensitive / control";
   cell.textLabel.font=[UIFont systemFontOfSize:12];
   cell.textLabel.numberOfLines=0;cell.textLabel.textColor=UIColor.secondaryLabelColor;
   cell.selectionStyle=UITableViewCellSelectionStyleNone;
  }
 }
 return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
 [tableView deselectRowAtIndexPath:indexPath animated:YES];
 if(indexPath.section==0&&indexPath.row==1){
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"监听端口" message:@"1024–65535，修改后自动重启服务。" preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.keyboardType=UIKeyboardTypeNumberPad;field.text=[NSString stringWithFormat:@"%lu",(unsigned long)[FLEXDylixMCPServer port]];}];
  [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
   NSUInteger port=[alert.textFields.firstObject.text integerValue];
   if(port<1024||port>65535)return;
   [FLEXDylixMCPServer setPort:port];
   if([FLEXDylixMCPServer isEnabled]){[[FLEXDylixMCPServer shared] stop];[[FLEXDylixMCPServer shared] start];}
   [self reloadSoon];
  }]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 if(indexPath.section==0&&indexPath.row==2){
  UIPasteboard.generalPasteboard.string=[FLEXDylixMCPServer endpoint];
  [self toast:@"已复制访问地址"];return;
 }
 if(indexPath.section==2&&indexPath.row==0){
  NSString *url=[FLEXDylixMCPServer endpoint],*json;
  if([FLEXDylixMCPServer authRequired])json=[NSString stringWithFormat:@"{\"mcpServers\":{\"flex\":{\"type\":\"http\",\"url\":\"%@\",\"headers\":{\"Authorization\":\"Bearer %@\"}}}}",url,[FLEXDylixMCPServer token]];
  else json=[NSString stringWithFormat:@"{\"mcpServers\":{\"flex\":{\"type\":\"http\",\"url\":\"%@\"}}}",url];
  UIPasteboard.generalPasteboard.string=json;
  [self toast:@"已复制 MCP 客户端配置"];return;
 }
 if(indexPath.section==1&&![FLEXDylixMCPServer authRequired]&&indexPath.row>=1&&indexPath.row<=3){[self toast:@"当前已关闭授权保护"];return;}
 if(indexPath.section==1&&indexPath.row==1){
  NSString *token=[FLEXDylixMCPServer token];UIPasteboard.generalPasteboard.string=token;
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"访问令牌" message:token preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 if(indexPath.section==1&&indexPath.row==2){
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"自定义授权码" message:@"8–64 位字母、数字、点、下划线或短横线。" preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
   field.placeholder=@"输入授权码";
   field.autocapitalizationType=UITextAutocapitalizationTypeNone;
   field.autocorrectionType=UITextAutocorrectionTypeNo;
  }];
  [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
   if(![FLEXDylixMCPServer setToken:alert.textFields.firstObject.text]){[self toast:@"授权码格式不正确"];return;}
   if([FLEXDylixMCPServer isEnabled]){[[FLEXDylixMCPServer shared] stop];[[FLEXDylixMCPServer shared] start];}
   [self toast:@"已更新授权码"];
  }]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 if(indexPath.section==1&&indexPath.row==3){
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"重新生成令牌" message:@"旧令牌立即失效，需要同步修改电脑端 MCP 配置。" preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:@"重新生成" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
   [FLEXDylixMCPServer rotateToken];
   if([FLEXDylixMCPServer isEnabled]){[[FLEXDylixMCPServer shared] stop];[[FLEXDylixMCPServer shared] start];}
   [self toast:@"已生成新令牌"];
  }]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
}
- (void)toggleService:(UISwitch *)sender{
 [FLEXDylixMCPServer setEnabled:sender.on];
 if(sender.on)[[FLEXDylixMCPServer shared] start];else [[FLEXDylixMCPServer shared] stop];
 [self reloadSoon];
}
- (void)toggleGroup:(UISwitch *)sender{
 if(sender.tag==820){[FLEXDylixMCPServer setAuthRequired:sender.on];[self reloadSoon];return;}
 if(sender.tag==821)[FLEXDylixMCPServer setSensitiveEnabled:sender.on];
 else [FLEXDylixMCPServer setControlEnabled:sender.on];
 [self reloadSoon];
}
- (void)toast:(NSString *)text{
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:text message:nil preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:alert animated:YES completion:nil];
}
@end
