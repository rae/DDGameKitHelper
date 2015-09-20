//
//  DDGameKitHelper.h
//  Version 1.0
//
//  Inspired by Steffen Itterheim's GameKitHelper

#import <GameKit/GameKit.h>

@protocol DDGameKitHelperDelegate <NSObject>

@optional
-(BOOL) compareScore:(int64_t)score1 toScore:(int64_t)score2;
-(void) didSubmitScore:(int64_t)score;
-(void) didReportAchievement:(GKAchievement*)achievement;
-(void) didAcceptInvite:(GKInvite *)invite withPlayers:(NSArray *)playersToInvite;

@end

/// Helper class to simplify interactions with GameKit
@interface DDGameKitHelper : NSObject <GKGameCenterControllerDelegate>

@property (nonatomic, weak) id<DDGameKitHelperDelegate> delegate;
@property (nonatomic, copy) NSString* currentPlayerID;
@property (nonatomic, readonly) NSMutableDictionary* achievements;
@property (nonatomic, readonly) NSMutableDictionary* scores;
@property (nonatomic, readonly) NSMutableDictionary* achievementDescriptions;
@property (nonatomic, readonly, assign, getter = isLocalPlayerAuthenticating) BOOL localPlayerAuthenticating;
@property (nonatomic, strong) void (^preGameCenterHandler)();
@property (nonatomic, strong) void (^postGameCenterHandler)();

+(DDGameKitHelper*) sharedHelper;

-(void) authenticateLocalPlayer;
-(BOOL) localPlayerIsAuthenticated;

-(void) submitScore:(int64_t)value
	  toLeaderboard:(NSString*)category
		 showBanner:(BOOL)completionBanner;

-(void) reportAchievement:(NSString*)identifier
          percentProgress:(double)percent
			   showBanner:(BOOL)completionBanner;

-(void) resetAchievements;
-(void) showGameCenter;
-(void) showLeaderboard;
-(void) showLeaderboardCategory:(NSString*)category;
-(void) showAchievements;
-(GKAchievementDescription*) achievementDescriptionForId:(NSString*)identifier;
- (NSUInteger) numberOfTotalAchievements;
- (NSUInteger) numberOfCompletedAchievements;

@end
