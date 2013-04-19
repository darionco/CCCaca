//
//  CCDirectorIOS+CCDirectorIOS_CCCacaScreenFilter.m
//  Mega Run
//
//  Created by Dario Segura on 2013-04-15.
//
//

#import "CCDirectorIOS+CCCacaScreenFilter.h"
#import "CCScheduler.h"
#import "cocos2d.h"
#import <objc/runtime.h>

// COCOS 2.1 COMPATIBILITY LAYER //
#if COCOS2D_VERSION == 0x00020100
#   define isPaused_ _isPaused
#   define scheduler_ _scheduler
#   define dt _dt
#   define nextScene_ _nextScene
#   define runningScene_ _runningScene
#   define notificationNode_ _notificationNode
#   define displayStats_ _displayStats
#   define totalFrames_ _totalFrames
#endif

// COCOS 0.99 COMPATIBILITY LAYER //
#if !defined(CC_ARC_RETAIN)
#   if defined(__has_feature) && __has_feature(objc_arc)
        // ARC (used for inline functions)
#       define CC_ARC_RETAIN(value)	value
#       define CC_ARC_RELEASE(value)	value = 0
#       define CC_ARC_UNSAFE_RETAINED	__unsafe_unretained

#   else
        // No ARC
#       define CC_ARC_RETAIN(value)	[value retain]
#       define CC_ARC_RELEASE(value)	[value release]
#       define CC_ARC_UNSAFE_RETAINED
#   endif
#endif

#pragma mark - CCDirectorIOS Forward Declarations
@interface CCDirectorIOS (CCCacaScreenFilterForwardDeclarations) // will not be implemented //
-(void) calculateDeltaTime;
-(void) setNextScene;
#if COCOS2D_VERSION <= 0x00010100
-(void) showFPS;
#elif COCOS2D_VERSION > 0x00010100
-(void) showStats;
-(void) calculateMPF;
#endif
@end

#pragma mark - CCDirector (CCCacaScreenFilter)
@implementation CCDirectorIOS (CCCacaScreenFilter)
-(CCCacaScreenFilter**) getCCCacaScreenFilterVar
{
    static CCCacaScreenFilter *__CCCacaScreenFilter__ = nil;
    return &__CCCacaScreenFilter__;
}

-(void) setCCCacaFilter:(CCCacaScreenFilter*)screenFilter
{
    CCCacaScreenFilter **cacaFilter = [self getCCCacaScreenFilterVar];
    if ((*cacaFilter) || !screenFilter)
    {
        [(*cacaFilter) onExit];
        CC_ARC_RELEASE((*cacaFilter));
        (*cacaFilter) = nil;
    }
    (*cacaFilter) = CC_ARC_RETAIN(screenFilter);
    [(*cacaFilter) onEnter];
}

-(void) drawSceneCCCacaSceneFilter
{
#if COCOS2D_VERSION <= 0x00010100
    
    
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
    
    
#elif COCOS2D_VERSION > 0x00010100
    
    
    /* calculate "global" dt */
	[self calculateDeltaTime];
    
	CCGLView *openGLview = (CCGLView*)[self view];
    
	[EAGLContext setCurrentContext: [openGLview context]];
    
	/* tick before glClear: issue #533 */
	if( ! isPaused_ )
		[scheduler_ update: dt];
    
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
	/* to avoid flickr, nextScene MUST be here: after tick and before draw.
	 XXX: Which bug is this one. It seems that it can't be reproduced with v0.9 */
	if( nextScene_ )
		[self setNextScene];
    
	kmGLPushMatrix();
    
	CCCacaScreenFilter *cacaFilter = (*[self getCCCacaScreenFilterVar]);
    cacaFilter.sceneToFilter = runningScene_;
    [cacaFilter visit];
    
	[notificationNode_ visit];
    
	if( displayStats_ )
		[self showStats];
    
	kmGLPopMatrix();
    
	totalFrames_++;
    
	[openGLview swapBuffers];
    
	if( displayStats_ )
		[self calculateMPF];
    
    
#endif
}

+(IMP) getCCCacaDrawSceneMethod
{
    static IMP __CCCacaDrawSceneMethod__ = nil;
    if (!__CCCacaDrawSceneMethod__)
    {
        __CCCacaDrawSceneMethod__ = method_getImplementation(class_getInstanceMethod([CCDirectorIOS class], @selector(drawSceneCCCacaSceneFilter)));
    }
    return __CCCacaDrawSceneMethod__;
}

@end
