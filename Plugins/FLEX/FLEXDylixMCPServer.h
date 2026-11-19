#import <Foundation/Foundation.h>

// Injected-app MCP endpoint. Runs inside the host process, reuses the FLEX
// runtime, and never talks to the Dylix app. The bearer token and each tool
// group are explicit grants stored for that host app.
@interface FLEXDylixMCPServer : NSObject
+ (instancetype)shared;
+ (BOOL)isEnabled;
+ (void)setEnabled:(BOOL)enabled;
+ (NSUInteger)port;
+ (void)setPort:(NSUInteger)port;
+ (NSString *)token;
+ (NSString *)rotateToken;
+ (BOOL)sensitiveEnabled;
+ (void)setSensitiveEnabled:(BOOL)enabled;
+ (BOOL)controlEnabled;
+ (void)setControlEnabled:(BOOL)enabled;
+ (NSString *)endpoint;
+ (NSString *)status;
- (void)start;
- (void)stop;
@end
