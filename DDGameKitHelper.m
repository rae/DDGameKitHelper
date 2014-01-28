//
//  DDGameKitHelper.m
//  Version 1.0
//
//  Inspired by Steffen Itterheim's GameKitHelper

#import "DDGameKitHelper.h"
#import <CommonCrypto/CommonDigest.h>

static NSString* const kAchievementsFile = @".achievements";
static NSString* const kScoresFile = @".scores";

@interface DDGameKitHelper () <GKLocalPlayerListener>

@property (nonatomic, strong) NSMutableDictionary* achievements;
@property (nonatomic, strong) NSMutableDictionary* scores;
@property (nonatomic, strong) NSMutableDictionary* achievementDescriptions;
@property (nonatomic, assign, getter = isLocalPlayerAuthenticating) BOOL localPlayerAuthenticating;

@end

@implementation DDGameKitHelper

+(DDGameKitHelper*) sharedGameKitHelper
{
    static DDGameKitHelper *sInstanceOfGameKitHelper;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        sInstanceOfGameKitHelper = [[DDGameKitHelper alloc] init];
    });
 
    return sInstanceOfGameKitHelper;
}

-(NSString *) returnMD5Hash:(NSString*)concat 
{
    const char *concat_str = [concat UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(concat_str, (CC_LONG)strlen(concat_str), result);
    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < 16; i++)
    {
        [hash appendFormat:@"%02X", result[i]];
    }
    
    return [hash lowercaseString];
}

-(id) init
{
    if ((self = [super init]))
    {
        [self registerForLocalPlayerAuthChange];
    }
    
    return self;
}

-(void) dealloc
{
    [self saveScores];
    [self saveAchievements];
        
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


-(void) authenticateLocalPlayer
{
    self.localPlayerAuthenticating = YES;
    
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if (localPlayer.authenticateHandler == nil)
    {
        localPlayer.authenticateHandler = ^(UIViewController *viewController, NSError *error)
        {
            if(self.localPlayerAuthenticating) {
                self.localPlayerAuthenticating = NO;
            }
            
            if (error != nil)
            {
                NSLog(@"error authenticating player: %@", [error localizedDescription]);
            }
            else
            {
                GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
                if(localPlayer.isAuthenticated) {
                    [localPlayer registerListener:self];
                }
                
                if (viewController)
                {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^
                     {
                         [self presentViewController:viewController];
                     }];
                }
            }
        };
    }
}

- (void)player:(GKPlayer *)player didAcceptInvite:(GKInvite *)invite
{
    [self.delegate acceptedInvite:invite withPlayers:nil];
}

- (void)player:(GKPlayer *)player didRequestMatchWithPlayers:(NSArray *)playerIDsToInvite
{
    [self.delegate acceptedInvite:nil withPlayers:playerIDsToInvite];
}

-(BOOL) isLocalPlayerAuthenticated
{
	GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
	return localPlayer.authenticated;
}

-(void) onLocalPlayerAuthenticationChanged
{
    NSString* newPlayerID;
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    
    // if not authenticating then just return
    
    if (!localPlayer.isAuthenticated)
    {
        return;
    }
    
    NSLog(@"onLocalPlayerAuthenticationChanged. reloading scores and achievements and resynchronzing.");
    
    if (localPlayer.playerID != nil)
    {
        newPlayerID = [self returnMD5Hash:localPlayer.playerID];
    }
    else
    {
        newPlayerID = @"unknown";
    }
    
    if ([self.currentPlayerID isEqualToString:newPlayerID])
    {
        NSLog(@"player is the same");
        return;
    }
    
    self.currentPlayerID = newPlayerID;
    NSLog(@"currentPlayerID=%@", newPlayerID);
    
    [self initScores];
    [self initAchievements];
    
    [self synchronizeScores];
    [self synchronizeAchievements];
    [self loadAchievementDescriptions];
}

-(void) registerForLocalPlayerAuthChange
{
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(onLocalPlayerAuthenticationChanged) name:GKPlayerAuthenticationDidChangeNotificationName object:nil];
}

-(void) initScores
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString* file = [libraryPath stringByAppendingPathComponent:self.currentPlayerID];
    file = [file stringByAppendingString:kScoresFile];
    id object = [NSKeyedUnarchiver unarchiveObjectWithFile:file];
    
    if ([object isKindOfClass:[NSMutableDictionary class]])
    {
        NSMutableDictionary* loadedScores = (NSMutableDictionary*)object;
        self.scores = [[NSMutableDictionary alloc] initWithDictionary:loadedScores];
    }
    else
    {
        self.scores = [[NSMutableDictionary alloc] init];
    }
    
    NSLog(@"scores initialized: %lu", (unsigned long)self.scores.count);
}

-(void) initAchievements
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString* file = [libraryPath stringByAppendingPathComponent:self.currentPlayerID];
    file = [file stringByAppendingString:kAchievementsFile];
    id object = [NSKeyedUnarchiver unarchiveObjectWithFile:file];
    
    if ([object isKindOfClass:[NSMutableDictionary class]])
    {
        NSMutableDictionary* loadedAchievements = (NSMutableDictionary*)object;
        self.achievements = [[NSMutableDictionary alloc] initWithDictionary:loadedAchievements];
    }
    else
    {
        self.achievements = [[NSMutableDictionary alloc] init];
    }
    
    NSLog(@"achievements initialized: %lu", (unsigned long)self.achievements.count);
}

-(BOOL) compareScore:(GKScore *)score toScore:(GKScore *)otherScore
{
    if ([self.delegate respondsToSelector:@selector(compare:to:)])
    {
        return [self.delegate compare:score.value to:otherScore.value];
    }
    else
    {
        return score.value > otherScore.value;
    }
}

- (void) saveScores
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString* file = [libraryPath stringByAppendingPathComponent:self.currentPlayerID];
    file = [file stringByAppendingString:kScoresFile];
    [NSKeyedArchiver archiveRootObject:self.scores toFile:file];
    NSLog(@"scores saved: %lu", (unsigned long)self.scores.count);
}

-(void) saveAchievements
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString* file = [libraryPath stringByAppendingPathComponent:self.currentPlayerID];
    file = [file stringByAppendingString:kAchievementsFile];
    [NSKeyedArchiver archiveRootObject:self.achievements toFile:file];
    NSLog(@"achievements saved: %lu", (unsigned long)self.achievements.count);
}

-(void) synchronizeScores
{
    NSLog(@"synchronizing scores");
    
    // get the top score for each category for current player and compare it to the game center score for the same category
    
    [GKLeaderboard loadLeaderboardsWithCompletionHandler:^(NSArray *leaderboards, NSError *error)
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^
        {
            if (error != nil)
            {
                NSLog(@"unable to synchronize scores");
                return;
            }
            
            NSString* playerId = [GKLocalPlayer localPlayer].playerID;
            
            for (GKLeaderboard *globalLeaderboard in leaderboards)
            {
                NSString *identifier = globalLeaderboard.identifier;
                
                GKLeaderboard *leaderboardRequest = [[GKLeaderboard alloc] initWithPlayerIDs:@[playerId]];
                leaderboardRequest.identifier = identifier;
                leaderboardRequest.timeScope = GKLeaderboardTimeScopeAllTime;
                leaderboardRequest.range = NSMakeRange(1,1);
                [leaderboardRequest loadScoresWithCompletionHandler: ^(NSArray *playerScores, NSError *error)
                 {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^
                     {
                        if (error != nil)
                        {
                            NSLog(@"unable to synchronize scores");
                            return;
                        }
                        
                        GKScore* gcScore = nil;
                        if ([playerScores count] > 0)
                            gcScore = [playerScores firstObject];
                        GKScore* localScore = (self.scores)[identifier];
                        
                        //Must add the next two lines in order to prevent a 'A GKScore must contain an initialized value' crash
                        GKScore *toReport = [[GKScore alloc] initWithLeaderboardIdentifier:identifier];
                        toReport.value = localScore.value;
                        
                        if (gcScore == nil && localScore == nil)
                        {
                            NSLog(@"%@(%lld,%lld): no score yet. nothing to synch", identifier, gcScore.value, localScore.value);
                        }
                        
                        else if (gcScore == nil)
                        {
                            NSLog(@"%@(%lld,%lld): gc score missing. reporting local score", identifier, gcScore.value, localScore.value);
                            [GKScore reportScores:@[localScore] withCompletionHandler:^(NSError* error) {}];
                        }
                        
                        else if (localScore == nil)
                        {
                            NSLog(@"%@(%lld,%lld): local score missing. caching gc score", identifier, gcScore.value, localScore.value);
                            (self.scores)[gcScore.leaderboardIdentifier] = gcScore;
                            [self saveScores];
                        }
                        
                        else if ([self compareScore:localScore toScore:gcScore])
                        {
                            NSLog(@"%@(%lld,%lld): local score more current than gc score. reporting local score", identifier, gcScore.value, localScore.value);
                            [GKScore reportScores:@[toReport] withCompletionHandler:^(NSError* error) {}];
                        }
                        
                        else if ([self compareScore:gcScore toScore:localScore])
                        {
                            NSLog(@"%@(%lld,%lld): gc score is more current than local score. caching gc score", identifier, gcScore.value, localScore.value);
                            (self.scores)[gcScore.leaderboardIdentifier] = gcScore;
                            [self saveScores];
                        }
                        
                        else
                        {
                            NSLog(@"%@(%lld,%lld): scores are equal. nothing to synch", identifier, gcScore.value, localScore.value);
                        }
                    }];
                }];
            }
        }];
    }];
}

-(void) synchronizeAchievements
{
    NSLog(@"synchronizing achievements");
    
    // get the achievements from game center
    
    [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray* gcAchievementsArray, NSError* error)
     {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^
         {
            if (error != nil)
            {
                NSLog(@"unable to synchronize achievements");
                return;
            }
            
            // convert NSArray into NSDictionary for ease of use
            NSMutableDictionary *gcAchievements = [[NSMutableDictionary alloc] init];
            for (GKAchievement* gcAchievement in gcAchievementsArray)
            {
                gcAchievements[gcAchievement.identifier] = gcAchievement;
            }
            
            // find local achievements not yet reported in game center and report them
            for (NSString* identifier in self.achievements)
            {
                GKAchievement *gcAchievement = gcAchievements[identifier];
                if (gcAchievement == nil)
                {
                    NSLog(@"achievement %@ not in game center. reporting it", identifier);
                    [self.achievements[identifier] reportAchievementWithCompletionHandler:^(NSError* error) {}];
                }
            }
            
            // find game center achievements that are not reported locally and store them
            for (GKAchievement* gcAchievement in gcAchievementsArray)
            {
                GKAchievement* localAchievement = self.achievements[gcAchievement.identifier];
                if (localAchievement == nil)
                {
                    NSLog(@"achievement %@ not stored locally. storing it", gcAchievement.identifier);
                    self.achievements[gcAchievement.identifier] = gcAchievement;
                }
            }
            
            [self saveAchievements];
        }];
    }];
}



-(void) submitScore:(int64_t)value
leaderboardIdentifier:(NSString*)category
withCompletionBanner:(BOOL)completionBanner
{
    // always report the new score
    NSLog(@"reporting score of %lld for %@", value, category);
    GKScore* newScore = [[GKScore alloc] initWithLeaderboardIdentifier:category];
    newScore.value = value;
    [GKScore reportScores:@[newScore] withCompletionHandler:^(NSError* error)
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^
         {
            // if it's better than the previous score, then save it and notify the user
            GKScore* score = [self getScoreByCategory:category];
            if ([self compareScore:newScore toScore:score])
            {
                NSLog(@"new high score of %lld for %@", score.value, category);
                score.value = value;
                [self saveScores];
                
                if (completionBanner)
                {
                    [GKNotificationBanner showBannerWithTitle:NSLocalizedString(@"New High Score", @"New High Score Game Center banner message")
                                                      message:[NSString stringWithFormat:@"%lld", value]
                                            completionHandler:nil];
                }
                
                if ([self.delegate respondsToSelector:@selector(onSubmitScore:)])
                {
                    [self.delegate onSubmitScore:value];
                }
            }
        }];
    }];
}

-(GKScore*) getScoreByCategory:(NSString*)category
{
    GKScore* score = self.scores[category];
    
    if (score == nil)
    {
        score = [[GKScore alloc] initWithLeaderboardIdentifier:category];
        score.value = 0;
        self.scores[category] = score;
    }
    
    return score;
}

-(void) reportAchievement:(NSString*)identifier
          percentComplete:(double)percent
     withCompletionBanner:(BOOL)completionBanner
{
    GKAchievement* achievement = [self getAchievement:identifier];
    if (achievement.percentComplete < percent)
    {
        NSLog(@"new achievement %@ reported", achievement.identifier);
        achievement.percentComplete = percent;
        achievement.showsCompletionBanner = completionBanner;
        [GKAchievement reportAchievements:@[achievement] withCompletionHandler:^(NSError* error)
         {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^
             {
                if ([self.delegate respondsToSelector:@selector(onReportAchievement:)])
                {
                    [self.delegate onReportAchievement:achievement];
                }
            }];
        }];
        
        [self saveAchievements];
    }
}

-(GKAchievement*) getAchievement:(NSString*)identifier
{
    GKAchievement* achievement = self.achievements[identifier];
    
    if (achievement == nil)
    {
        achievement = [[GKAchievement alloc] initWithIdentifier:identifier];
        self.achievements[achievement.identifier] = achievement;
    }
    
    return achievement;
}

- (void)loadAchievementDescriptions
{
    NSLog(@"loading achievement descriptions");
    
    [GKAchievementDescription loadAchievementDescriptionsWithCompletionHandler:^(NSArray *achievementDesc, NSError *error)
     {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^
         {
            self.achievementDescriptions = [[NSMutableDictionary alloc] init];
            
            if (error != nil)
            {
                NSLog(@"unable to load achievements");
                return;
            }
            
            for (GKAchievementDescription *description in achievementDesc)
            {
                self.achievementDescriptions[description.identifier] = description;
            }
            
            NSLog(@"achievement descriptions initialized: %lu", (unsigned long)self.achievementDescriptions.count);
        }];
    }];
}

-(GKAchievementDescription*) getAchievementDescription:(NSString*)identifier
{
    return self.achievementDescriptions[identifier];
}

-(void) resetAchievements
{
    [self.achievements removeAllObjects];
    [self saveAchievements];
    
    [GKAchievement resetAchievementsWithCompletionHandler:^(NSError* error) {}];
    
    NSLog(@"achievements reset");
}

-(UIViewController*) getRootViewController
{
    return [UIApplication sharedApplication].keyWindow.rootViewController;
}

-(void) presentViewController:(UIViewController*)vc
{
    UIViewController* rootVC = [self getRootViewController];
    [rootVC presentViewController:vc animated:YES completion:nil];
}

-(void) dismissModalViewController
{
    UIViewController* rootVC = [self getRootViewController];
    [rootVC dismissViewControllerAnimated:YES completion:nil];
}

-(void) showGameCenter
{
    if ([GKGameCenterViewController class])
    {
        GKGameCenterViewController *gameCenterController = [[GKGameCenterViewController alloc] init];
        if (gameCenterController != nil)
        {
            gameCenterController.gameCenterDelegate = self;
            [self presentViewController:gameCenterController];
        }
    }
    else
    {
        [self showLeaderboard];
    }
}

-(void) showLeaderboard
{
    GKGameCenterViewController* leaderboardVC = [[GKGameCenterViewController alloc] init];
    if (leaderboardVC != nil)
    {
        leaderboardVC.gameCenterDelegate = self;
        leaderboardVC.viewState = GKGameCenterViewControllerStateLeaderboards;
        [self presentViewController:leaderboardVC];
    }
}

-(void) showLeaderboardWithCategory:(NSString*)category
{
    GKGameCenterViewController* leaderboardVC = [[GKGameCenterViewController alloc] init];
    if (leaderboardVC != nil)
    {
        leaderboardVC.gameCenterDelegate = self;
        leaderboardVC.viewState = GKGameCenterViewControllerStateLeaderboards;
        leaderboardVC.leaderboardIdentifier = category;
        [self presentViewController:leaderboardVC];
    }  
}

-(void) showAchievements
{
    GKGameCenterViewController* achievementsVC = [[GKGameCenterViewController alloc] init];
    if (achievementsVC != nil)
    {
        achievementsVC.gameCenterDelegate = self;
        achievementsVC.viewState = GKGameCenterViewControllerStateAchievements;
        [self presentViewController:achievementsVC];
    }
}

- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController
{
    [self dismissModalViewController];
}

- (NSUInteger) numberOfTotalAchievements
{
    return [self.achievementDescriptions count];
}

- (NSUInteger) numberOfCompletedAchievements
{
    NSUInteger count = 0;
    for (GKAchievement* gcAchievement in [self.achievements objectEnumerator])
    {
        if (gcAchievement.completed)
            count++;
    }
    return count;
}

@end
