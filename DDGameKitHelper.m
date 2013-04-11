//
//  DDGameKitHelper.m
//  Version 1.0
//
//  Inspired by Steffen Itterheim's GameKitHelper

#import "DDGameKitHelper.h"
#import <CommonCrypto/CommonDigest.h>

static NSString* const kAchievementsFile = @".achievements";
static NSString* const kScoresFile = @".scores";

@interface DDGameKitHelper ()

@property (nonatomic, strong) NSMutableDictionary* achievements;
@property (nonatomic, strong) NSMutableDictionary* scores;
@property (nonatomic, strong) NSMutableDictionary* achievementDescriptions;

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
    CC_MD5(concat_str, strlen(concat_str), result);
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
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if (localPlayer.authenticateHandler == nil)
    {
        localPlayer.authenticateHandler = ^(UIViewController *viewController, NSError *error)
        {
            if (error != nil)
            {
                NSLog(@"error authenticating player: %@", [error localizedDescription]);
            }
            
            if (viewController)
            {
                [self presentViewController:viewController];
            }
        };
    }
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
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
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
    
    NSLog(@"scores initialized: %d", self.scores.count);
}

-(void) initAchievements
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
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
    
    NSLog(@"achievements initialized: %d", self.achievements.count);
}

-(BOOL) compareScore:(GKScore *)score toScore:(GKScore *)otherScore
{
    if (self.delegate)
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
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:self.currentPlayerID];
    file = [file stringByAppendingString:kScoresFile];
    [NSKeyedArchiver archiveRootObject:self.scores toFile:file];
    NSLog(@"scores saved: %d", self.scores.count);
}

-(void) saveAchievements
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:self.currentPlayerID];
    file = [file stringByAppendingString:kAchievementsFile];
    [NSKeyedArchiver archiveRootObject:self.achievements toFile:file];
    NSLog(@"achievements saved: %d", self.achievements.count);
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
                NSString *category = globalLeaderboard.category;
                
                GKLeaderboard *leaderboardRequest = [[GKLeaderboard alloc] initWithPlayerIDs:[NSArray arrayWithObject:playerId]];
                leaderboardRequest.category = category;
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
                            gcScore = [playerScores objectAtIndex:0];
                        GKScore* localScore = [self.scores objectForKey:category];
                        
                        //Must add the next two lines in order to prevent a 'A GKScore must contain an initialized value' crash
                        GKScore *toReport = [[GKScore alloc] initWithCategory:category];
                        toReport.value = localScore.value;
                        
                        if (gcScore == nil && localScore == nil)
                        {
                            NSLog(@"%@(%lld,%lld): no score yet. nothing to synch", category, gcScore.value, localScore.value);
                        }
                        
                        else if (gcScore == nil)
                        {
                            NSLog(@"%@(%lld,%lld): gc score missing. reporting local score", category, gcScore.value, localScore.value);
                            [localScore reportScoreWithCompletionHandler:^(NSError* error) {}];
                        }
                        
                        else if (localScore == nil)
                        {
                            NSLog(@"%@(%lld,%lld): local score missing. caching gc score", category, gcScore.value, localScore.value);
                            [self.scores setObject:gcScore forKey:gcScore.category];
                            [self saveScores];
                        }
                        
                        else if ([self compareScore:localScore toScore:gcScore])
                        {
                            NSLog(@"%@(%lld,%lld): local score more current than gc score. reporting local score", category, gcScore.value, localScore.value);
                            [toReport reportScoreWithCompletionHandler:^(NSError* error) {}];
                        }
                        
                        else if ([self compareScore:gcScore toScore:localScore])
                        {
                            NSLog(@"%@(%lld,%lld): gc score is more current than local score. caching gc score", category, gcScore.value, localScore.value);
                            [self.scores setObject:gcScore forKey:gcScore.category];
                            [self saveScores];
                        }
                        
                        else
                        {
                            NSLog(@"%@(%lld,%lld): scores are equal. nothing to synch", category, gcScore.value, localScore.value);
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
                [gcAchievements setObject:gcAchievement forKey:gcAchievement.identifier];
            }
            
            // find local achievements not yet reported in game center and report them
            for (NSString* identifier in self.achievements)
            {
                GKAchievement *gcAchievement = [gcAchievements objectForKey:identifier];
                if (gcAchievement == nil)
                {
                    NSLog(@"achievement %@ not in game center. reporting it", identifier);
                    [[self.achievements objectForKey:identifier] reportAchievementWithCompletionHandler:^(NSError* error) {}];
                }
            }
            
            // find game center achievements that are not reported locally and store them
            for (GKAchievement* gcAchievement in gcAchievementsArray)
            {
                GKAchievement* localAchievement = [self.achievements objectForKey:gcAchievement.identifier];
                if (localAchievement == nil)
                {
                    NSLog(@"achievement %@ not stored locally. storing it", gcAchievement.identifier);
                    [self.achievements setObject:gcAchievement forKey:gcAchievement.identifier];
                }
            }
            
            [self saveAchievements];
        }];
    }];
}



-(void) submitScore:(int64_t)value
           category:(NSString*)category
withCompletionBanner:(BOOL)completionBanner
{
    // always report the new score
    NSLog(@"reporting score of %lld for %@", value, category);
    GKScore* newScore = [[GKScore alloc] initWithCategory:category];
    newScore.value = value;
    [newScore reportScoreWithCompletionHandler:^(NSError* error)
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
    GKScore* score = [self.scores objectForKey:category];
    
    if (score == nil)
    {
        score = [[GKScore alloc] initWithCategory:category];
        score.value = 0;
        [self.scores setObject:score forKey:category];
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
        [achievement reportAchievementWithCompletionHandler:^(NSError* error)
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
    GKAchievement* achievement = [self.achievements objectForKey:identifier];
    
    if (achievement == nil)
    {
        achievement = [[GKAchievement alloc] initWithIdentifier:identifier];
        [self.achievements setObject:achievement forKey:achievement.identifier];
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
                [self.achievementDescriptions setObject:description forKey:description.identifier];
            }
            
            NSLog(@"achievement descriptions initialized: %d", self.achievementDescriptions.count);
        }];
    }];
}

-(GKAchievementDescription*) getAchievementDescription:(NSString*)identifier
{
    GKAchievementDescription* description = [self.achievementDescriptions objectForKey:identifier];
    return description;    
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

- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController
{
    [self dismissModalViewController];
}

-(void) showLeaderboard
{
    GKLeaderboardViewController* leaderboardVC = [[GKLeaderboardViewController alloc] init];
    if (leaderboardVC != nil)
    {
        leaderboardVC.leaderboardDelegate = self;
        [self presentViewController:leaderboardVC];
    }
}

-(void) showLeaderboardwithCategory:(NSString*)category timeScope:(GKLeaderboardTimeScope)tscope
{
    GKLeaderboardViewController* leaderboardVC = [[GKLeaderboardViewController alloc] init];
    if (leaderboardVC != nil)
    {
        leaderboardVC.leaderboardDelegate = self;
        leaderboardVC.category = category;
        leaderboardVC.timeScope = tscope;
        [self presentViewController:leaderboardVC];
    }  
}

-(void) leaderboardViewControllerDidFinish:(GKLeaderboardViewController*)viewController
{
    [self dismissModalViewController];
}

-(void) showAchievements
{
    GKAchievementViewController* achievementsVC = [[GKAchievementViewController alloc] init];
    if (achievementsVC != nil)
    {
        achievementsVC.achievementDelegate = self;
        [self presentViewController:achievementsVC];
    }
}

-(void) achievementViewControllerDidFinish:(GKAchievementViewController*)viewController
{
    [self dismissModalViewController];
}

@end
