#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Live FLEX surface used by the MCP adapter. Implemented by DXFlexBridge and
// replicated by the Foundation-only regression harness.
@protocol DXMCPFlex <NSObject>
- (NSArray<NSDictionary *> *)liveDevices;
- (void)enqueueForDevice:(NSString *)device operation:(NSString *)operation arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary * _Nullable result,NSError * _Nullable error))completion;
@end
// Streamable HTTP MCP server (JSON-RPC 2.0) that forwards tools to the paired
// FLEX++ dylib inside the target app. Tools stay hidden unless the service and
// their group (read / sensitive / control) are enabled on the phone.
@interface DXRemoteMCP : NSObject
+ (BOOL)serviceEnabled;
+ (void)setServiceEnabled:(BOOL)enabled;
+ (NSArray<NSString *> *)groups;
+ (BOOL)groupEnabled:(NSString *)group;
+ (void)setGroup:(NSString *)group enabled:(BOOL)enabled;
+ (NSDictionary *)groupStates;
- (instancetype)initWithFlex:(id<DXMCPFlex>)flex;
// Completion may be delivered from any queue with a complete HTTP response dictionary.
- (void)handle:(NSDictionary *)request complete:(void (^)(NSDictionary *response))complete;
@end
NS_ASSUME_NONNULL_END
