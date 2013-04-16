//
//  CCCacaScreenFilter.h
//  Mega Run
//
//  Created by Dario Segura on 2013-04-03.
//
//

#import <Foundation/Foundation.h>
#import "CCScene.h"
#import "caca.h"

extern const NSString *kCCCacaRender32bitColor;
extern const NSString *kCCCacaRender16bitColor;
extern const NSString *kCCCacaRender8bitColor;
extern const NSString *kCCCacaRenderLightnessGray;
extern const NSString *kCCCacaRenderAverageGray;
extern const NSString *kCCCacaRenderLuminosityGray;
extern const NSString *kCCCacaRenderLibCacaColor;

extern const NSString *kCCCacaAntialiasNone;
extern const NSString *kCCCacaAntialiasPrefilter;

extern const NSString *kCCCacaDitherNone;
extern const NSString *kCCCacaDitherOrdered2;
extern const NSString *kCCCacaDitherOrdered4;
extern const NSString *kCCCacaDitherOrdered8;
extern const NSString *kCCCacaDitherRandom;
extern const NSString *kCCCacaDitherFloydSteinberg;

// function pointer for the color rendering functions //
typedef ccColor4B(*GetColorMethod)(id, SEL, int);
// function pointer for the CCDirectorIOS drawScene function //
typedef void(*CCDirectorIOSDrawScene)(id, SEL);

@interface CCCacaScreenFilter : CCScene
{
    GLuint m_frameBuffer;
    GLuint m_renderBuffer;
    CGSize m_backingSize;
    GLuint m_fontSize;
    CGSize m_cacaContextSize;
    CCScene *m_sceneToFilter;
    GLuint m_totalCacaQuads;
    
    CGSize m_fontQuad;
    
    GLushort *m_indices;
    
    NSDictionary *m_fontDictionary;
    
    ccV3F_C4B_T2F_Quad *m_quadBuffers[2]; // multithread support //
    GLuint m_workingQuadBuffer;
    GLuint m_renderQuadBuffer;
    
    caca_canvas_t *m_cacaCanvas;
    caca_dither_t *m_cacaDither;
    
    GLubyte *m_pixelBuffer;
    
    SEL m_getColorSEL;
    GetColorMethod m_getColorMethod;
    uint8_t m_customColorShift;
    
    // multithreading //
    NSCondition *m_workerThreadCondition;
    NSLock *m_workerThreadLock;
    NSThread *m_workerThread;
    
    // enabling filter //
    BOOL m_enabled;
}

@property (nonatomic, retain) CCScene *sceneToFilter;
@property (nonatomic, readonly) BOOL enabled;
@property (atomic, assign) uint8_t customColorShift; // should be a number between 1 and 7 // maybe add a check in the assign method? // -Dario //
@property (atomic, assign) const NSString *renderColorMode;
@property (atomic, assign) const NSString *antialiasMode;
@property (atomic, assign) const NSString *ditherMode;
@property (atomic) float gamma;

+(NSDictionary*) createTextureForFontSize:(NSUInteger)fontSize inFontQuad:(CGSize)fontQuad forCacaDither:(caca_dither_t*)cacaDither;
-(id) initWithFontSize:(GLuint)fontSize;
-(BOOL) toggle;
-(void) enable;
-(void) disable;

@end
