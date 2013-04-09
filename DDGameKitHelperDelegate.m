//
//  DDGameKitHelperDelegate.h
//  Version 1.0

#import "DDGameKitHelperDelegate.h"
#import <GameKit/GameKit.h>

@implementation DDGameKitHelperDelegate

// display new high score
-(void) onSubmitScore:(int64_t)score
{
    [GKNotificationBanner showBannerWithTitle:NSLocalizedString(@"New High Score", @"New High Score Game Center banner message")
                                      message:[NSString stringWithFormat:@"%lld", score]
                            completionHandler:nil];
}

@end
