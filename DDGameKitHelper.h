//
//  DDGameKitHelper.h
//  Version 1.0
//
//  Inspired by Steffen Itterheim's GameKitHelper

#import <GameKit/GameKit.h>

@protocol DDGameKitHelperDelegate <NSObject>

@optional
-(BOOL) compare:(int64_t)score1 to:(int64_t)score2;
-(void) onSubmitScore:(int64_t)score;
-(void) onReportAchievement:(GKAchievement*)achievement;
-(void) acceptedInvite:(GKInvite *)acceptedInvite withPlayers:(NSArray *)playersToInvite;

@end

@interface DDGameKitHelper : NSObject <GKLeaderboardViewControllerDelegate, GKAchievementViewControllerDelegate, GKGameCenterControllerDelegate>

@property (nonatomic, weak) id<DDGameKitHelperDelegate> delegate;

@property (nonatomic, copy) NSString* currentPlayerID;
@property (nonatomic, readonly) NSMutableDictionary* achievements;
@property (nonatomic, readonly) NSMutableDictionary* scores;
@property (nonatomic, readonly) NSMutableDictionary* achievementDescriptions;
@property (nonatomic, readonly, assign, getter = isLocalPlayerAuthenticating) BOOL localPlayerAuthenticating;

+(DDGameKitHelper*) sharedGameKitHelper;

-(void) authenticateLocalPlayer;

-(BOOL) isLocalPlayerAuthenticated;

-(void) submitScore:(int64_t)value
           category:(NSString*)category
withCompletionBanner:(BOOL)completionBanner;

-(void) reportAchievement:(NSString*)identifier
          percentComplete:(double)percent
     withCompletionBanner:(BOOL)completionBanner;

-(void) resetAchievements;

-(void) showGameCenter;

-(void) showLeaderboard;

-(void) showLeaderboardwithCategory:(NSString*)category timeScope:(GKLeaderboardTimeScope)tscope;

-(void) showAchievements;

-(GKAchievementDescription*) getAchievementDescription:(NSString*)identifier;

@end
