CCCaca
======

ASCII Art for Cocos2D iOS 1.x (Can be easily ported to 2.x)

What can I do with CCCaca?
--------------------------
CCCaca was designed as a screen filter to render your Cocos2D applications in ASCII art using different predefined color sets. It uses a dumbed down version of [libCaca][1] called [hayCaca (i-caca)][2] under the hood.

How fast is CCCaca?
-------------------
The filter speed depends on device and font size, the smaller the font, the slower the render. On an iPhone 4S I found a font size of 7 to be a good compromise between quality and speed.

Why was CCCaca created?
-----------------------
Mostly, for fun.

How do I use CCCaca?
--------------------
Add the "src" folder to your project, then:

	#import "CCCacaScreenFilter.h"
	// ... code code code code ... //
		CCCacaScreenFilter *screenFilter = [[CCCacaScreenFilter alloc] initWithFontSize:fontSize];
		[screenFilter enable];

That's all, enjoy ASCII! Make sure to keep a pointer to your *screenFilter* variable so you can disable the filter later using:

	[screenFilter disable];

Anything else I need to know?
-----------------------------
Maybe?

   * Be aware that CCCaca uses two memory buffers equal to the number of pixels on the device's screen in 32bit.
   * The rendering is multithreaded, be carful if you modify it.
   * CCCaca depends on having an untouched CCDirectorIOS *drawScene* method, it uses method swizzling to plugin itself.
   * Changing the *gamma* property only affects colors using the *kCCCacaRenderLibCacaColor* render color mode.

Licensing
---------
libCaca and hayCaca are released under the *Do What the Fuck You Want to Public License* (WTFPL).
CCCaca might be released under the compatible MIT license, it doesn't have one yet.



[1]: http://caca.zoy.org/wiki/libcaca
[2]: http://github.com/darionco/hayCaca
