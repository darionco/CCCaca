//
//  CCDirectorIOS+CCCacaScreenFilter.h
//  Mega Run
//
//  Created by Dario Segura on 2013-04-15.
//
//

#import "CCDirectorIOS.h"
#import "CCCacaScreenFilter.h"

@interface CCDirectorIOS (CCCacaScreenFilter)
-(CCCacaScreenFilter**) getCCCacaScreenFilterVar;
-(void) setCCCacaFilter:(CCCacaScreenFilter*)screenFilter;
-(void) drawSceneCCCacaSceneFilter;
@end
