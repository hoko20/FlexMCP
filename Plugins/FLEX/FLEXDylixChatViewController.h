#import <UIKit/UIKit.h>

@interface FLEXDylixChatViewController : UIViewController
@property(nonatomic,copy) NSString *(^reportProvider)(void);
@property(nonatomic,weak) id selectedObject;
- (instancetype)initWithReport:(NSString *)report className:(NSString *)className;
- (void)updateReport:(NSString *)report className:(NSString *)className selectedObject:(id)object;
// Used by the in-app MCP endpoint to reach the window operations that belong
// to this controller. Returns nil once this chat has been released.
+ (instancetype)dylixCurrentChat;
- (void)performWindowOperation:(NSString *)operation arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *result, NSString *error))completion;
@end
