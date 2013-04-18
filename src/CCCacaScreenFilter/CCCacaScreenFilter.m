//
//  CCCacaScreenFilter.m
//  Mega Run
//
//  Created by Dario Segura on 2013-04-03.
//
//

#import <objc/runtime.h>
#import "CCCacaScreenFilter.h"
#import "CCDirector.h"
#import "CCGL.h"
#import "ccMacros.h"
#import "ccUtils.h"
#import "CCDirectorIOS+CCCacaScreenFilter.h"
//#import "CCGLProgram.h"
#import "cocos2d.h"

#pragma mark - CCCaca Defines
#define CC_CACA_FONT_NAME "AmericanTypewriter-Bold"
#define CC_CACA_SCALE_FACTOR CC_CONTENT_SCALE_FACTOR()

#pragma mark - NSString Constants
const NSString *kCCCacaRender32bitColor = @"_getColor32BitForIndex:";
const NSString *kCCCacaRender16bitColor = @"_getColor16BitForIndex:";
const NSString *kCCCacaRender8bitColor = @"_getColor8BitForIndex:";
const NSString *kCCCacaRenderLightnessGray = @"_getColorLightnessGrayForIndex:";
const NSString *kCCCacaRenderAverageGray = @"_getColorAverageGrayForIndex:";
const NSString *kCCCacaRenderLuminosityGray = @"_getColorLuminosityGrayForIndex:";
const NSString *kCCCacaRenderLibCacaColor = @"_getColorLibCacaColorForIndex:";

const NSString *kCCCacaAntialiasNone = @"none";
const NSString *kCCCacaAntialiasPrefilter = @"prefilter";

const NSString *kCCCacaDitherNone = @"none";
const NSString *kCCCacaDitherOrdered2 = @"ordered2";
const NSString *kCCCacaDitherOrdered4 = @"ordered4";
const NSString *kCCCacaDitherOrdered8 = @"ordered8";
const NSString *kCCCacaDitherRandom = @"random";
const NSString *kCCCacaDitherFloydSteinberg = @"fstein";

#pragma mark - libCaca's forward struct declarations
enum color_mode
{
    COLOR_MODE_MONO,
    COLOR_MODE_GRAY,
    COLOR_MODE_8,
    COLOR_MODE_16,
    COLOR_MODE_FULLGRAY,
    COLOR_MODE_FULL8,
    COLOR_MODE_FULL16
};

struct caca_dither
{
    int bpp, has_palette, has_alpha;
    int w, h, pitch;
    int rmask, gmask, bmask, amask;
    int rright, gright, bright, aright;
    int rleft, gleft, bleft, aleft;
    void (*get_hsv)(caca_dither_t *, char *, int, int);
    int red[256], green[256], blue[256], alpha[256];
    
    /* Colour features */
    float gamma, brightness, contrast;
    int gammatab[4097];
    
    /* Dithering features */
    char const *antialias_name;
    int antialias;
    
    char const *color_name;
    enum color_mode color;
    
    char const *algo_name;
    void (*init_dither) (int);
    int (*get_dither) (void);
    void (*increment_dither) (void);
    
    char const *glyph_name;
    uint32_t const * glyphs;
    int glyph_count;
    
    int invert;
};

#pragma mark - CCCacaScreenFilter (Internal)
@interface CCCacaScreenFilter (Internal)
-(int) _getPixelIndexForQuadIndex:(int)index;
-(ccColor4B) _getColor32BitForIndex:(int)index;
-(ccColor4B) _getColor16BitForIndex:(int)index;
-(ccColor4B) _getColorLightnessGrayForIndex:(int)index;
-(ccColor4B) _getColorAverageGrayForIndex:(int)index;
-(ccColor4B) _getColorLuminosityGrayForIndex:(int)index;
-(ccColor4B) _getColorLibCacaColorForIndex:(int)index;

-(void) _workerThreadFunction;
@end


#pragma mark - CCCacaScreenFilter
@implementation CCCacaScreenFilter
{} // harmless hack to make Xcode see the next pragma mark :) //

#pragma mark - Properties
@synthesize sceneToFilter = m_sceneToFilter;
@synthesize enabled = m_enabled;
@synthesize customColorShift = m_customColorShift;

-(NSString*) renderColorMode
{
    return NSStringFromSelector(m_getColorSEL);;
}

-(void) setRenderColorMode:(NSString *)renderColorMode
{
    [m_workerThreadLock lock];
    m_getColorSEL = NSSelectorFromString(renderColorMode);
    m_getColorMethod = (GetColorMethod)[self methodForSelector:m_getColorSEL];
    [m_workerThreadLock unlock];
}

-(NSString*) antialiasMode
{
    return [NSString stringWithUTF8String:caca_get_dither_antialias(m_cacaDither)];
}

-(void) setAntialiasMode:(NSString *)antialiasMode
{
    [m_workerThreadLock lock];
    caca_set_dither_antialias(m_cacaDither, [antialiasMode UTF8String]);
    [m_workerThreadLock unlock];
}

-(NSString*) ditherMode
{
    return [NSString stringWithUTF8String:caca_get_dither_algorithm(m_cacaDither)];
}

-(void) setDitherMode:(NSString *)ditherMode
{
    [m_workerThreadLock lock];
    caca_set_dither_algorithm(m_cacaDither, [ditherMode UTF8String]);
    [m_workerThreadLock unlock];
}

-(float) gamma
{
    return caca_get_dither_gamma(m_cacaDither);
}

-(void) setGamma:(float)gamma
{
    [m_workerThreadLock lock];
    caca_set_dither_gamma(m_cacaDither, gamma);
    [m_workerThreadLock unlock];
}

#pragma mark - Static Methods
+(NSDictionary*) createTextureForFontSize:(NSUInteger)fontSize inFontQuad:(CGSize)fontQuad forCacaDither:(caca_dither_t*)cacaDither
{
    GLuint gridSize = ceilf(sqrtf(cacaDither->glyph_count));
    GLuint textureWidth = fontQuad.width * gridSize;
    GLuint textureHeight = fontQuad.height * gridSize;
    NSUInteger POTWide = ccNextPOT(textureWidth);
	NSUInteger POTHigh = ccNextPOT(textureHeight);
    CGRect glyphRenderRect = CGRectMake(0, 0, fontQuad.width, fontQuad.height);
    
    // allocate a buffer for the data //
    unsigned char *data = calloc(POTHigh, POTWide); // this can be very wasteful ut it's ok for now // TODO: Make it use the least amount of memory possible //
    
    // create the texture //
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
	CGContextRef context = CGBitmapContextCreate(data, POTWide, POTHigh, 8, POTWide, colorSpace, kCGImageAlphaNone);
	CGColorSpaceRelease(colorSpace);
	
	if(!context)
    {
		free(data);
        CC_ARC_RELEASE(self);
		return nil;
	}
	
    // initialize the dictionary //
    NSMutableDictionary *retDictionary = [[NSMutableDictionary alloc] init];
    
    // create a uifont for drawing //
    UIFont *uiFont = [UIFont fontWithName:@CC_CACA_FONT_NAME size:fontSize * CC_CACA_SCALE_FACTOR];
    CGContextSetTextDrawingMode(context, kCGTextFill);
    CGContextSetGrayFillColor(context, 0.25f, 1.0f);
    CGContextFillRect(context, CGRectMake(0, 0, POTWide, POTHigh));
    CGContextSetGrayFillColor(context, 1.0f, 1.0f);
    UIGraphicsPushContext(context);
    for (int i = 0; i < cacaDither->glyph_count; ++i)
    {
        // advance the rect //
        glyphRenderRect.origin.x = fontQuad.width * (i % gridSize);
        glyphRenderRect.origin.y = POTHigh - fontQuad.height - (fontQuad.height * ((int)i / gridSize));
        
        // create a string from the character //
        NSString *charString = [[NSString alloc] initWithFormat:@"%c", cacaDither->glyphs[i]];
        
        // calculate the right point to render the text //
        CGSize charSize = [charString sizeWithFont:uiFont];
        CGPoint charPoint = CGPointMake(glyphRenderRect.origin.x + (glyphRenderRect.size.width * 0.5f) - (charSize.width * 0.5f),
                                        glyphRenderRect.origin.y + (glyphRenderRect.size.height * 0.5f) - (charSize.height * 0.5f));
        
        // draw the text //
        [charString drawAtPoint:charPoint withFont:uiFont];
        
        // save the glyph data //
        [retDictionary setObject:[NSValue valueWithCGRect:CGRectMake(glyphRenderRect.origin.x / POTWide,
                                                                     (fontQuad.height * ((int)i / gridSize)) / POTHigh,
                                                                     glyphRenderRect.size.width / POTWide,
                                                                     glyphRenderRect.size.height / POTHigh)] forKey:charString];
        
        // clean up //
        CC_ARC_RELEASE(charString);
        
    }
    UIGraphicsPopContext();
    // clean up //
	CGContextRelease(context);
    
    // upload the texture to opengl //
    GLuint name = 0;
    glPixelStorei(GL_UNPACK_ALIGNMENT,1);
    glGenTextures(1, &name);
    glBindTexture(GL_TEXTURE_2D, name);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, (GLsizei)POTWide, (GLsizei)POTHigh, 0, GL_ALPHA, GL_UNSIGNED_BYTE, data);
    
    // clean up //
	free(data);
    
    // save the texture name //
    [retDictionary setObject:[NSNumber numberWithUnsignedInteger:name] forKey:@"texture"];
    
    return retDictionary;
}

#pragma mark - Methods
-(id) init
{
    return [self initWithFontSize:8];
}

-(id) initWithFontSize:(GLuint)fontSize
{
    self = [super init];
    if (self)
    {
        GLint oldFrameBuffer;
        GLint oldRenderBuffer;
        
        
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldFrameBuffer);
        glGetIntegerv(GL_RENDERBUFFER_BINDING, &oldRenderBuffer); // not compatible with OSX :( // for now! //
        
        m_backingSize = [[CCDirector sharedDirector] winSizeInPixels];
        
        glGenFramebuffers(1, &m_frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, m_frameBuffer);
        
        glGenRenderbuffers(1, &m_renderBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, m_renderBuffer);
        glRenderbufferStorage(GL_RENDERBUFFER,
                                 GL_RGBA8_OES,
                                 m_backingSize.width,
                                 m_backingSize.height);
        
        glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                                     GL_COLOR_ATTACHMENT0,
                                     GL_RENDERBUFFER,
                                     m_renderBuffer);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Error creating framebuffer!");
        
        glBindFramebuffer(GL_FRAMEBUFFER, oldFrameBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, oldRenderBuffer);
        
        m_fontSize = fontSize;
        
        // calculate the font size //
        CGFontRef font = CGFontCreateWithFontName(CFSTR(CC_CACA_FONT_NAME));
        CGRect fontRect = CGFontGetFontBBox(font);
        CGFloat units = CGFontGetUnitsPerEm(font);
        
        m_fontQuad = CGSizeMake(ceilf(((fontRect.size.width - fontRect.origin.x) / units) * m_fontSize * 0.325f * CC_CACA_SCALE_FACTOR), // the text's bounding box seees too wide, 0.325 is there to compensate, this number was eyeballed :( //
                                    ceilf(((fontRect.size.height - fontRect.origin.y) / units) * m_fontSize * 0.4875f * CC_CACA_SCALE_FACTOR)); // the text's bounding box seees too high, 0.4875 is there to compensate, this number was eyeballed :( //
        
        CGFontRelease(font);
        
        // create the grid //
        m_cacaContextSize = CGSizeMake(floorf(m_backingSize.width / m_fontQuad.width) + (((((int)m_backingSize.width) % ((int)m_fontQuad.width)) ? 1 : 0)),
                                       floorf(m_backingSize.height / m_fontQuad.height) + ((((int)m_backingSize.height) % ((int)m_fontQuad.height)) ? 1 : 0));
        
        m_totalCacaQuads = m_cacaContextSize.width * m_cacaContextSize.height;
        // initialize the quad buffers //
        m_quadBuffers[0] = (ccV3F_C4B_T2F_Quad*)malloc(sizeof(ccV3F_C4B_T2F_Quad) * m_totalCacaQuads);
        m_quadBuffers[1] = (ccV3F_C4B_T2F_Quad*)malloc(sizeof(ccV3F_C4B_T2F_Quad) * m_totalCacaQuads);
        m_indices = (GLushort*)malloc(sizeof(GLushort) * m_totalCacaQuads * 6);
        m_workingQuadBuffer = 0;
        m_renderQuadBuffer = 1;
        
        // initialize libcaca //
        m_cacaCanvas = caca_create_canvas(m_cacaContextSize.width, m_cacaContextSize.height);
        m_customColorShift = 2;
        NSAssert(m_cacaCanvas, @"Error initializing libCaca");
        
        m_pixelBuffer = (GLubyte*)malloc(sizeof(GLubyte) * m_backingSize.width * m_backingSize.height * 4);
        uint32_t amask = 0xff000000;
        uint32_t bmask = 0x00ff0000;
        uint32_t gmask = 0x0000ff00;
        uint32_t rmask = 0x000000ff;
        
        m_cacaDither = caca_create_dither(32, m_backingSize.width, m_backingSize.height, m_backingSize.width * 4,
                                          rmask, gmask, bmask, amask);
        caca_set_dither_color(m_cacaDither, "16");
        
        self.ditherMode = kCCCacaDitherNone;
        self.antialiasMode = kCCCacaAntialiasNone;
        self.renderColorMode = kCCCacaRender32bitColor;
        
        
        // get the font dictionary //
        m_fontDictionary = [[self class] createTextureForFontSize:m_fontSize inFontQuad:m_fontQuad forCacaDither:m_cacaDither];
        
        // initialize all the vertices //
        for (int i = 0; i < m_totalCacaQuads; ++i)
        {
            for (int b = 0; b < 2; ++b) // repeat once per buffer // this is for multithreading //
            {
                float x = (i % ((int)m_cacaContextSize.width));
                float y = ((int)(i / m_cacaContextSize.width));
                
                // Atlas: Vertex
                float x1 = x * m_fontQuad.width;
                float y1 = y * m_fontQuad.height;
                float x2 = x1 + m_fontQuad.width;
                float y2 = y1 + m_fontQuad.height;
                
                // Don't update Z.
                m_quadBuffers[b][i].bl.vertices = (ccVertex3F) { x1, y1, 0 };
                m_quadBuffers[b][i].br.vertices = (ccVertex3F) { x2, y1, 0 };
                m_quadBuffers[b][i].tl.vertices = (ccVertex3F) { x1, y2, 0 };
                m_quadBuffers[b][i].tr.vertices = (ccVertex3F) { x2, y2, 0 };
                
                ccColor4B color = ccc4(0x00, 0x00, 0xff, 0xff);
                m_quadBuffers[b][i].bl.colors = color;
                m_quadBuffers[b][i].br.colors = color;
                m_quadBuffers[b][i].tl.colors = color;
                m_quadBuffers[b][i].tr.colors = color;
                
                // indices //
                m_indices[i * 6/* + 0*/] = (i * 4)/* + 0*/;
                m_indices[i * 6 + 1] = (i * 4) + 1;
                m_indices[i * 6 + 2] = (i * 4) + 2;
                
                m_indices[i * 6 + 3] = (i * 4) + 1;
                m_indices[i * 6 + 4] = (i * 4) + 2;
                m_indices[i * 6 + 5] = (i * 4) + 3;
                
            }
        }
        
#if COCOS2D_VERSION > 0x00010100
        // set the gl program //
        self.shaderProgram = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_PositionTextureA8Color];
        self.anchorPoint = CGPointZero;
#endif
        
        // disable the filter by default //
        m_enabled = NO;
        
        // setup multithreading //
        m_workerThreadCondition = [[NSCondition alloc] init];
        m_workerThreadLock = [[NSLock alloc] init];
        
        [NSThread detachNewThreadSelector:@selector(_workerThreadFunction) toTarget:self withObject:nil];
    }
    
    return self;
}

-(void) dealloc
{
    [m_workerThreadLock lock];
    [m_workerThreadCondition lock];
    [m_workerThread cancel];
    [m_workerThreadCondition signal];
    [m_workerThreadCondition unlock];
    
    free(m_indices);
    GLuint name = [[m_fontDictionary objectForKey:@"texture"] unsignedIntegerValue];
    glDeleteTextures(1, &name);
    CC_ARC_RELEASE(m_fontDictionary);
    free(m_quadBuffers[0]);
    free(m_quadBuffers[1]);
    glDeleteFramebuffers(1, &m_frameBuffer);
    glDeleteRenderbuffers(1, &m_renderQuadBuffer);
    free(m_pixelBuffer);
    
    CC_ARC_RELEASE(m_workerThreadCondition);
    CC_ARC_RELEASE(m_workerThreadLock);
    
    [super dealloc];
}

-(BOOL) toggle
{
    if (!m_enabled)
    {
        [((CCDirectorIOS*)[CCDirectorIOS sharedDirector]) setCCCacaFilter:self];
        if (method_getImplementation(class_getInstanceMethod([CCDirectorIOS class], @selector(drawScene))) != [CCDirectorIOS getCCCacaDrawSceneMethod])
        {
            method_exchangeImplementations(class_getInstanceMethod([CCDirectorIOS class], @selector(drawScene)), class_getInstanceMethod([CCDirectorIOS class], @selector(drawSceneCCCacaSceneFilter)));
        }
    }
    else
    {
        [((CCDirectorIOS*)[CCDirectorIOS sharedDirector]) setCCCacaFilter:nil];
        method_exchangeImplementations(class_getInstanceMethod([CCDirectorIOS class], @selector(drawScene)), class_getInstanceMethod([CCDirectorIOS class], @selector(drawSceneCCCacaSceneFilter)));
    }
    m_enabled = !m_enabled;
    return m_enabled;
}

// convenience functions //
-(void) enable
{
    if (!m_enabled)
    {
        [self toggle];
    }
}

-(void) disable
{
    if (m_enabled)
    {
        [self toggle];
    }
}

//-(void) addFilterToCurrentScene
//{
//    self.sceneToFilter = [[CCDirector sharedDirector] runningScene];
//    //[[CCDirector sharedDirector] replaceScene:self];
//    object_setInstanceVariable([CCDirector sharedDirector], "runningScene_", self);
//}
//
//-(void) removeFilterFromCurrentScene
//{
//    //[[CCDirector sharedDirector] replaceScene:m_sceneToFilter];
//    object_setInstanceVariable([CCDirector sharedDirector], "runningScene_", self.sceneToFilter);
//    self.sceneToFilter = nil;
//}

#pragma mark - Internal
-(int) _getPixelIndexForQuadIndex:(int)index
{
    GLuint centerX = (m_quadBuffers[m_workingQuadBuffer][index].tl.vertices.x + ((m_quadBuffers[m_workingQuadBuffer][index].tr.vertices.x - m_quadBuffers[m_workingQuadBuffer][index].tl.vertices.x) / 2));
    GLuint centerY = (m_quadBuffers[m_workingQuadBuffer][index].bl.vertices.y + ((m_quadBuffers[m_workingQuadBuffer][index].tl.vertices.y - m_quadBuffers[m_workingQuadBuffer][index].bl.vertices.y) / 2));
    centerX = (centerX >= m_backingSize.width) ? (m_backingSize.width - 1) : centerX;
    centerY = (centerY >= m_backingSize.height) ? (m_backingSize.height - 1) : centerY;
    return (centerY * ((int)m_backingSize.width) * 4) + (centerX * 4);
}

-(ccColor4B) _getColor32BitForIndex:(int)index
{
    GLuint pixelIndex = [self _getPixelIndexForQuadIndex:index];
    return ((ccColor4B){m_pixelBuffer[pixelIndex], m_pixelBuffer[pixelIndex + 1], m_pixelBuffer[pixelIndex + 2], 0xff});
}

-(ccColor4B) _getColor16BitForIndex:(int)index
{
#define CC_CACA_16_BIT_SHIFT 4 // RGBA4444
    GLuint pixelIndex = [self _getPixelIndexForQuadIndex:index];
    return ((ccColor4B){((m_pixelBuffer[pixelIndex] >> CC_CACA_16_BIT_SHIFT) << CC_CACA_16_BIT_SHIFT),
                        ((m_pixelBuffer[pixelIndex + 1] >> CC_CACA_16_BIT_SHIFT) << CC_CACA_16_BIT_SHIFT),
                        ((m_pixelBuffer[pixelIndex + 2] >> CC_CACA_16_BIT_SHIFT) << CC_CACA_16_BIT_SHIFT),
                        0xff});
}

-(ccColor4B) _getColor8BitForIndex:(int)index
{
#define CC_CACA_8_BIT_SHIFT 6 // RGBA2222
    GLuint pixelIndex = [self _getPixelIndexForQuadIndex:index];
    return ((ccColor4B){((m_pixelBuffer[pixelIndex] >> CC_CACA_8_BIT_SHIFT) << CC_CACA_8_BIT_SHIFT),
        ((m_pixelBuffer[pixelIndex + 1] >> CC_CACA_8_BIT_SHIFT) << CC_CACA_8_BIT_SHIFT),
        ((m_pixelBuffer[pixelIndex + 2] >> CC_CACA_8_BIT_SHIFT) << CC_CACA_8_BIT_SHIFT),
        0xff});
}

-(ccColor4B) _getColorCustomForIndex:(int)index
{
    GLuint pixelIndex = [self _getPixelIndexForQuadIndex:index];
    return ((ccColor4B){((m_pixelBuffer[pixelIndex] >> m_customColorShift) << m_customColorShift),
        ((m_pixelBuffer[pixelIndex + 1] >> m_customColorShift) << m_customColorShift),
        ((m_pixelBuffer[pixelIndex + 2] >> m_customColorShift) << m_customColorShift),
        0xff});
}

-(ccColor4B) _getColorLightnessGrayForIndex:(int)index
{
    GLuint pixelIndex = [self _getPixelIndexForQuadIndex:index];
    GLubyte byteColor = (MAX(MAX(m_pixelBuffer[pixelIndex], m_pixelBuffer[pixelIndex + 1]) , m_pixelBuffer[pixelIndex + 2]) + MIN(MIN(m_pixelBuffer[pixelIndex], m_pixelBuffer[pixelIndex + 1]) , m_pixelBuffer[pixelIndex + 2])) / 2;
    return ((ccColor4B){byteColor, byteColor, byteColor, 0xff});
}

-(ccColor4B) _getColorAverageGrayForIndex:(int)index
{
    GLuint pixelIndex = [self _getPixelIndexForQuadIndex:index];
    GLubyte byteColor = (m_pixelBuffer[pixelIndex] + m_pixelBuffer[pixelIndex + 1] + m_pixelBuffer[pixelIndex + 2]) / 3;
    return ((ccColor4B){byteColor, byteColor, byteColor, 0xff});
}

-(ccColor4B) _getColorLuminosityGrayForIndex:(int)index
{
    GLuint pixelIndex = [self _getPixelIndexForQuadIndex:index];
    GLubyte byteColor = ((m_pixelBuffer[pixelIndex] * 0.21) + (m_pixelBuffer[pixelIndex + 1] * 0.71) + (m_pixelBuffer[pixelIndex + 2] * 0.07));
    return ((ccColor4B){byteColor, byteColor, byteColor, 0xff});
}

-(ccColor4B) _getColorLibCacaColorForIndex:(int)index
{
    uint16_t fg = caca_attr_to_rgb12_fg(caca_get_canvas_attrs(m_cacaCanvas)[index]);
    return ((ccColor4B){((fg & 0xf00) >> 8) * 8, ((fg & 0x0f0) >> 4) * 8, (fg & 0x00f) * 8, 0xFF });
}

-(void) _workerThreadFunction
{
    m_workerThread = [NSThread currentThread];
    [m_workerThread setThreadPriority:1.0];
    [m_workerThreadLock lock];
    while (1)
    {
        @autoreleasepool
        {
            [m_workerThreadCondition lock];
            if([[NSThread currentThread] isCancelled])
            {
                [m_workerThreadLock unlock];
                [m_workerThreadCondition unlock];
                [NSThread exit];
                return;
            }
            [m_workerThreadLock unlock];
            [m_workerThreadCondition wait];
            [m_workerThreadLock lock];
            [m_workerThreadCondition unlock];
            
            caca_dither_bitmap(m_cacaCanvas, 0, 0, m_cacaContextSize.width, m_cacaContextSize.height, m_cacaDither, m_pixelBuffer);
            const uint32_t *characters = caca_get_canvas_chars(m_cacaCanvas);
            
            for (int i = 0; i < m_totalCacaQuads; ++i)
            {
                
                if(characters[i] <= 0x00000020 || characters[i] == CACA_MAGIC_FULLWIDTH)
                {
                    ccColor4B color4 = {0x0, 0x0, 0x0, 0xFF };
                    
                    m_quadBuffers[m_workingQuadBuffer][i].bl.colors = color4;
                    m_quadBuffers[m_workingQuadBuffer][i].br.colors = color4;
                    m_quadBuffers[m_workingQuadBuffer][i].tl.colors = color4;
                    m_quadBuffers[m_workingQuadBuffer][i].tr.colors = color4;
                    
                    m_quadBuffers[m_workingQuadBuffer][i].bl.texCoords.u = 0;
                    m_quadBuffers[m_workingQuadBuffer][i].bl.texCoords.v = 0;
                    m_quadBuffers[m_workingQuadBuffer][i].br.texCoords.u = 0;
                    m_quadBuffers[m_workingQuadBuffer][i].br.texCoords.v = 0;
                    m_quadBuffers[m_workingQuadBuffer][i].tl.texCoords.u = 0;
                    m_quadBuffers[m_workingQuadBuffer][i].tl.texCoords.v = 0;
                    m_quadBuffers[m_workingQuadBuffer][i].tr.texCoords.u = 0;
                    m_quadBuffers[m_workingQuadBuffer][i].tr.texCoords.v = 0;
                    
                    continue;
                }
                
                ccColor4B color4 = m_getColorMethod(self, m_getColorSEL, i);
                
                m_quadBuffers[m_workingQuadBuffer][i].bl.colors = color4;
                m_quadBuffers[m_workingQuadBuffer][i].br.colors = color4;
                m_quadBuffers[m_workingQuadBuffer][i].tl.colors = color4;
                m_quadBuffers[m_workingQuadBuffer][i].tr.colors = color4;
                
                // set the texture coords //
                CGRect textureCoords = [[m_fontDictionary objectForKey:[NSString stringWithFormat:@"%c", characters[i]]] CGRectValue];
                
                float left,right,top,bottom;
                left	= textureCoords.origin.x;
                right	= left + textureCoords.size.width;
                top		= textureCoords.origin.y;
                bottom	= top + textureCoords.size.height;
                m_quadBuffers[m_workingQuadBuffer][i].bl.texCoords.u = left;
                m_quadBuffers[m_workingQuadBuffer][i].bl.texCoords.v = top;
                m_quadBuffers[m_workingQuadBuffer][i].br.texCoords.u = right;
                m_quadBuffers[m_workingQuadBuffer][i].br.texCoords.v = top;
                m_quadBuffers[m_workingQuadBuffer][i].tl.texCoords.u = left;
                m_quadBuffers[m_workingQuadBuffer][i].tl.texCoords.v = bottom;
                m_quadBuffers[m_workingQuadBuffer][i].tr.texCoords.u = right;
                m_quadBuffers[m_workingQuadBuffer][i].tr.texCoords.v = bottom;
            }
        }
    }
}

#pragma mark - CCNode Overrides
-(void) visit
{
    if ([m_workerThreadLock tryLock])
    {
        [m_workerThreadCondition lock];
        m_renderQuadBuffer = m_workingQuadBuffer;
        m_workingQuadBuffer = (m_workingQuadBuffer + 1) % 2;
        [m_workerThreadCondition signal];
        [m_workerThreadCondition unlock];
        
        GLint oldFrameBuffer;
        GLint oldRenderBuffer;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldFrameBuffer);
        glGetIntegerv(GL_RENDERBUFFER_BINDING, &oldRenderBuffer); // not compatible with OSX :( // for now! //
        
        glBindFramebuffer(GL_FRAMEBUFFER, m_frameBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, m_renderBuffer);
        
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        [m_sceneToFilter visit];
        
        glReadPixels(0, 0, m_backingSize.width, m_backingSize.height, GL_RGBA, GL_UNSIGNED_BYTE, m_pixelBuffer);
        
        glBindFramebuffer(GL_FRAMEBUFFER, oldFrameBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, oldRenderBuffer);
        
        [m_workerThreadLock unlock];
    }
    
    [super visit];
}

-(void) draw
{
#if COCOS2D_VERSION == 0x00010100
    
    
    #define kQuadSize sizeof(m_quadBuffers[m_renderQuadBuffer][0].bl)
    glBindTexture(GL_TEXTURE_2D, [[m_fontDictionary objectForKey:@"texture"] unsignedIntegerValue]);
    
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    long offset = (long)&m_quadBuffers[m_renderQuadBuffer][0];
    
    // vertex
    NSInteger diff = offsetof( ccV3F_C4B_T2F, vertices);
    glVertexPointer(3, GL_FLOAT, kQuadSize, (void*) (offset + diff) );
    
    // color
    diff = offsetof( ccV3F_C4B_T2F, colors);
    glColorPointer(4, GL_UNSIGNED_BYTE, kQuadSize, (void*)(offset + diff));
    
    // tex coords
    diff = offsetof( ccV3F_C4B_T2F, texCoords);
    glTexCoordPointer(2, GL_FLOAT, kQuadSize, (void*)(offset + diff));
    
    //glDrawArrays(GL_TRIANGLE_STRIP, 0, 4/* * m_totalCacaQuads*/);
    glDrawElements(GL_TRIANGLES, m_totalCacaQuads * 6, GL_UNSIGNED_SHORT, m_indices);
    
    glBlendFunc(CC_BLEND_SRC, CC_BLEND_DST);
    
    
#elif COCOS2D_VERSION > 0x00010100
    
    kmGLPushMatrix();
    self.scale = (1.0f / CC_CACA_SCALE_FACTOR);
    [self transform];
    
	CC_NODE_DRAW_SETUP();
    
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
	glBindTexture(GL_TEXTURE_2D, [[m_fontDictionary objectForKey:@"texture"] unsignedIntegerValue]);
    
	//
	// Attributes
	//
    
	ccGLEnableVertexAttribs( kCCVertexAttribFlag_PosColorTex );
    
    #define kQuadSize sizeof(m_quadBuffers[m_renderQuadBuffer][0].bl)
	long offset = (long)&m_quadBuffers[m_renderQuadBuffer][0];
    
	// vertex
	NSInteger diff = offsetof( ccV3F_C4B_T2F, vertices);
	glVertexAttribPointer(kCCVertexAttrib_Position, 3, GL_FLOAT, GL_FALSE, kQuadSize, (void*) (offset + diff));
    
	// texCoods
	diff = offsetof( ccV3F_C4B_T2F, texCoords);
	glVertexAttribPointer(kCCVertexAttrib_TexCoords, 2, GL_FLOAT, GL_FALSE, kQuadSize, (void*)(offset + diff));
    
	// color
	diff = offsetof( ccV3F_C4B_T2F, colors);
	glVertexAttribPointer(kCCVertexAttrib_Color, 4, GL_UNSIGNED_BYTE, GL_TRUE, kQuadSize, (void*)(offset + diff));
    
    
	glDrawElements(GL_TRIANGLES, m_totalCacaQuads * 6, GL_UNSIGNED_SHORT, m_indices);
    
    ccGLBlendFunc(CC_BLEND_SRC, CC_BLEND_DST);
    
	CHECK_GL_ERROR_DEBUG();
	CC_INCREMENT_GL_DRAWS(1);

    self.scale = 1.0f;
    kmGLPopMatrix();
    
#endif
}

@end


