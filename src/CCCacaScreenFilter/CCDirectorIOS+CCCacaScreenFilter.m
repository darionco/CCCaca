//
//  CCDirectorIOS+CCDirectorIOS_CCCacaScreenFilter.m
//  Mega Run
//
//  Created by Dario Segura on 2013-04-15.
//
//

#import "CCDirectorIOS+CCCacaScreenFilter.h"
#import "CCScheduler.h"
#import "ccMacros.h"

#pragma mark - CCDirectorIOS Forward Declarations
@interface CCDirectorIOS (CCCacaScreenFilterForwardDeclarations) // will not be implemented //
-(void) calculateDeltaTime;
-(void) setNextScene;
-(void) showFPS;
@end

#pragma mark - CCDirector (CCCacaScreenFilter)
@implementation CCDirectorIOS (CCCacaScreenFilter)
-(CCCacaScreenFilter**) getCCCacaScreenFilterVar
{
    static CCCacaScreenFilter **__CCCacaScreenFilter__ = nil;
    if (!__CCCacaScreenFilter__)
    {
        __CCCacaScreenFilter__ = (CCCacaScreenFilter**)malloc(sizeof(CCCacaScreenFilter*));
        (*__CCCacaScreenFilter__) = nil;
    }
    return __CCCacaScreenFilter__;
}

-(void) setCCCacaFilter:(CCCacaScreenFilter*)screenFilter
{
    CCCacaScreenFilter **cacaFilter = [self getCCCacaScreenFilterVar];
    if ((*cacaFilter) || !screenFilter)
    {
        [(*cacaFilter) release];
        (*cacaFilter) = nil;
    }
    (*cacaFilter) = [screenFilter retain];
}

-(void) drawSceneCCCacaSceneFilter
{
    /* calculate "global" dt */
	[self calculateDeltaTime];
	
	/* tick before glClear: issue #533 */
	if( ! isPaused_ ) {
		[[CCScheduler sharedScheduler] tick: dt];
	}
	
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	/* to avoid flickr, nextScene MUST be here: after tick and before draw.
	 XXX: Which bug is this one. It seems that it can't be reproduced with v0.9 */
	if( nextScene_ )
		[self setNextScene];
	
	glPushMatrix();
	
	[self applyOrientation];
	
	// By default enable VertexArray, ColorArray, TextureCoordArray and Texture2D
	CC_ENABLE_DEFAULT_GL_STATES();
	
	/* draw the scene */
    CCCacaScreenFilter *cacaFilter = (*[self getCCCacaScreenFilterVar]);
    cacaFilter.sceneToFilter = runningScene_;
    [cacaFilter visit];
	
	/* draw the notification node */
	[notificationNode_ visit];
    
	if( displayFPS_ )
		[self showFPS];
	
#if CC_ENABLE_PROFILERS
	[self showProfilers];
#endif
	
	CC_DISABLE_DEFAULT_GL_STATES();
	
	glPopMatrix();
	
	totalFrames_++;
    
	[openGLView_ swapBuffers];
}
@end
