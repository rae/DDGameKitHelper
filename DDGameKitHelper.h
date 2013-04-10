//
//  DDGameKitHelper.h
//  Version 1.0
//
//  Inspired by Steffen Itterheim's GameKitHelper

#import <GameKit/GameKit.h>

@protocol DDGameKitHelperProtocol <NSObject>

@optional
-(bool) compare:(int64_t)score1 to:(int64_t)score2;
-(void) onSubmitScore:(int64_t)score;
-(void) onReportAchievement:(GKAchievement*)achievement;

@end

@interface DDGameKitHelper : NSObject <GKLeaderboardViewControllerDelegate, GKAchievementViewControllerDelegate, GKGameCenterControllerDelegate>
{
    id<DDGameKitHelperProtocol> delegate;
    NSMutableDictionary* achievements;
    NSMutableDictionary* scores;
    NSMutableDictionary* achievementDescriptions;
    NSString* currentPlayerID;
}

@property (nonatomic, retain) id<DDGameKitHelperProtocol> delegate;
@property (nonatomic, readonly) NSMutableDictionary* achievements;
@property (nonatomic, readonly) NSMutableDictionary* scores;
@property (nonatomic, readonly) NSMutableDictionary* achievementDescriptions;
@property (nonatomic, retain) NSString* currentPlayerID;

+(DDGameKitHelper*) sharedGameKitHelper;

-(void) authenticateLocalPlayer;

-(bool) isLocalPlayerAuthenticated;

-(void) submitScore:(int64_t)value category:(NSString*)category;

-(void) reportAchievement:(NSString*)identifier
          percentComplete:(double)percent
     withCompletionBanner:(bool)completionBanner;

-(void) resetAchievements;

-(void) showGameCenter;

-(void) showLeaderboard;

-(void) showLeaderboardwithCategory:(NSString*)category timeScope:(int)tscope;

-(void) showAchievements;

-(GKAchievementDescription*) getAchievementDescription:(NSString*)identifier;

@end
