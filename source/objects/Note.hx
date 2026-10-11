package objects;

import backend.animation.PsychAnimationController;
import backend.NoteTypesConfig;
import backend.NoteSkinData;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;

import objects.StrumNote;

import flixel.math.FlxRect;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

typedef NoteSplashData = {
	disabled:Bool,
	texture:String,
	useGlobalShader:Bool, //breaks r/g/b but makes it copy default colors for your custom note
	useRGBShader:Bool,
	antialiasing:Bool,
	r:FlxColor,
	g:FlxColor,
	b:FlxColor,
	a:Float
}

/**
 * The note object used as a data structure to spawn and manage notes during gameplay.
 * 
 * If you want to make a custom note type, you should search for: "function set_noteType"
**/
class Note extends NoteSkinSprite
{
	//This is needed for the hardcoded note types to appear on the Chart Editor,
	//It's also used for backwards compatibility with 0.1 - 0.3.2 charts.
	public static final defaultNoteTypes:Array<String> = [
		'', //Always leave this one empty pls
		'Alt Animation',
		'Hey!',
		'Hurt Note',
		'GF Sing',
		'No Animation'
	];

	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var strumTime:Float = 0;
	public var noteData:Int = 0;
	public var keyCount:Int;
	/** Multiplier for custom scripts that specify their own 4K graphic size. */
	public var multikeyScale(get, never):Float;
	function get_multikeyScale():Float return KeyMode.scale(keyCount);
	public var singDirection(get, never):Int;
	function get_singDirection():Int return KeyMode.singDirection(keyCount, noteData);
	public var styleOverride:Int = -1;
	public var noteStyle(get, never):Int;
	function get_noteStyle():Int return styleOverride >= 0 ? styleOverride : KeyMode.style(keyCount, noteData);
	public var animColor(get, never):String;
	function get_animColor():String return KeyMode.colors[noteStyle];
	var pixelColumns:Int = 4;

	public var mustPress:Bool = false;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;

	public var wasGoodHit:Bool = false;
	public var missed:Bool = false;

	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;

	public var spawned:Bool = false;

	public var tail:Array<Note> = []; // for sustains
	public var parent:Note;
	
	public var blockHit:Bool = false; // only works for player

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var noteType(default, set):String = null;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var rgbShader:RGBShaderReference;
	public static var globalRgbShaders:Array<RGBPalette> = [];
	public var inEditor:Bool = false;
	public var colorSkinImage(default, null):String;
	public var usesDefaultColorsImage(default, null):Bool = false;

	public var animSuffix:String = '';
	public var gfNote:Bool = false;
	public var earlyHitMult:Float = 1;
	public var lateHitMult:Float = 1;
	public var lowPriority:Bool = false;

	public static var SUSTAIN_SIZE:Int = 44;
	public static var swagWidth:Float = 160 * 0.7;
	public static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
	public static var defaultNoteSkin(default, never):String = 'noteSkins/NOTE_assets';

	public var noteSplashData:NoteSplashData = {
		disabled: false,
		texture: null,
		antialiasing: !PlayState.isPixelStage,
		useGlobalShader: false,
		useRGBShader: (PlayState.SONG != null) ? !(PlayState.SONG.disableNoteRGB == true) : true,
		r: -1,
		g: -1,
		b: -1,
		a: ClientPrefs.data.splashAlpha
	};

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed(default, set):Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.02;
	public var missHealth:Float = 0.1;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; //plan on doing scroll directions soon -bb

	public var hitsoundDisabled:Bool = false;
	public var hitsoundChartEditor:Bool = true;
	/**
	 * Forces the hitsound to be played even if the user's hitsound volume is set to 0
	**/
	public var hitsoundForce:Bool = false;
	public var hitsoundVolume(get, default):Float = 1.0;
	function get_hitsoundVolume():Float {
		if(ClientPrefs.data.hitsoundVolume > 0)
			return ClientPrefs.data.hitsoundVolume;
		return hitsoundForce ? hitsoundVolume : 0.0;
	}
	public var hitsound:String = 'hitsound';

	private function set_multSpeed(value:Float):Float {
		resizeByRatio(value / multSpeed);
		multSpeed = value;
		//trace('fuck cock');
		return value;
	}

	public function resizeByRatio(ratio:Float) //haha funny twitter shit
	{
		if(isSustainNote && animation.curAnim != null && !animation.curAnim.name.endsWith('end'))
		{
			scale.y *= ratio;
			updateHitbox();
		}
	}

	private function set_texture(value:String):String {
		if(texture != value) reloadNote(value);

		texture = value;
		return value;
	}

	public function defaultRGB()
	{
		var arr:Array<FlxColor> = NoteSkinData.getColors(null, colorSkinImage)[noteStyle];

		if (arr != null && arr.length == 3)
		{
			rgbShader.r = arr[0];
			rgbShader.g = arr[1];
			rgbShader.b = arr[2];
		}
		else
		{
			rgbShader.r = 0xFFFF0000;
			rgbShader.g = 0xFF00FF00;
			rgbShader.b = 0xFF0000FF;
		}
	}

	private function set_noteType(value:String):String {
		noteSplashData.texture = PlayState.SONG != null ? PlayState.SONG.splashSkin : 'noteSplashes/noteSplashes';
		defaultRGB();

		if(noteData > -1 && noteType != value) {
			switch(value) {
				case 'Hurt Note':
					ignoreNote = mustPress;
					//reloadNote('HURTNOTE_assets');
					//this used to change the note texture to HURTNOTE_assets.png,
					//but i've changed it to something more optimized with the implementation of RGBPalette:

					// note colors
					rgbShader.r = 0xFF101010;
					rgbShader.g = 0xFFFF0000;
					rgbShader.b = 0xFF990022;

					// splash data and colors
					noteSplashData.r = 0xFFFF0000;
					noteSplashData.g = 0xFF101010;
					noteSplashData.texture = 'noteSplashes/noteSplashes-electric';

					// gameplay data
					lowPriority = true;
					missHealth = isSustainNote ? 0.25 : 0.1;
					hitCausesMiss = true;
					hitsound = 'cancelMenu';
					hitsoundChartEditor = false;
				case 'Alt Animation':
					animSuffix = '-alt';
				case 'No Animation':
					noAnimation = true;
					noMissAnimation = true;
				case 'GF Sing':
					gfNote = true;
			}
			if (value != null && value.length > 1) NoteTypesConfig.applyNoteTypeData(this, value);
			if (hitsound != 'hitsound' && hitsoundVolume > 0) Paths.sound(hitsound); //precache new sound for being idiot-proof
			noteType = value;
			if (usesDefaultColorsImage && !rgbShader.allowNew) reloadNote(texture);
		}
		return value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false, ?createdFrom:Dynamic = null, keyCount:Int = 0, styleOverride:Int = -1)
	{
		super();

		animation = new PsychAnimationController(this);

		antialiasing = ClientPrefs.data.antialiasing;
		if(createdFrom == null) createdFrom = PlayState.instance;

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.inEditor = inEditor;
		this.moves = false;

		x += (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;
		this.strumTime = strumTime;
		if(!inEditor) this.strumTime += ClientPrefs.data.noteOffset;

		this.noteData = noteData;
		this.keyCount = keyCount > 0 ? keyCount : KeyMode.songKeys();
		this.styleOverride = styleOverride;

		if(noteData > -1)
		{
			rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteStyle));
			if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) rgbShader.enabled = false;
			texture = '';

			x += KeyMode.spacing(this.keyCount) * noteData;
			if(!isSustainNote) { //Doing this 'if' check to fix the warnings on Senpai songs
				var animToPlay:String = '';
				animToPlay = animColor;
				animation.play(animToPlay + 'Scroll');
			}
		}

		// trace(prevNote);

		if(prevNote != null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			alpha = 0.6;
			multAlpha = 0.6;
			hitsoundDisabled = true;
			if(ClientPrefs.data.downScroll) flipY = true;

			offsetX += width / 2;
			copyAngle = false;

			animation.play(animColor + 'holdend');

			updateHitbox();

			offsetX -= width / 2;

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play(prevNote.animColor + 'hold');

				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.05;
				if(createdFrom != null && createdFrom.songSpeed != null) prevNote.scale.y *= createdFrom.songSpeed;

				if(PlayState.isPixelStage) {
					prevNote.scale.y *= 1.19;
					prevNote.scale.y *= (6 / height); //Auto adjust note size
				}
				prevNote.updateHitbox();
				// prevNote.setGraphicSize();
			}

			if(PlayState.isPixelStage)
			{
				scale.y *= PlayState.daPixelZoom;
				updateHitbox();
			}
			earlyHitMult = 0;
		}
		else if(!isSustainNote)
		{
			centerOffsets();
			centerOrigin();
		}
		x += offsetX;
	}

	public static function initializeGlobalRGBShader(noteData:Int)
	{
		if(globalRgbShaders[noteData] == null)
		{
			var newRGB:RGBPalette = new RGBPalette();
			var arr:Array<FlxColor> = NoteSkinData.getColors()[noteData];
			
			if (arr != null && arr.length == 3)
			{
				newRGB.r = arr[0];
				newRGB.g = arr[1];
				newRGB.b = arr[2];
			}
			else
			{
				newRGB.r = 0xFFFF0000;
				newRGB.g = 0xFF00FF00;
				newRGB.b = 0xFF0000FF;
			}
			
			globalRgbShaders[noteData] = newRGB;
		}
		return globalRgbShaders[noteData];
	}

	var _lastNoteOffX:Float = 0;
	var sustainHeadFrameWidth:Float = 0;
	public var originalHeight:Float = 6;
	public var correctionOffset:Float = 0; //dont mess with this
	public function reloadNote(texture:String = '', postfix:String = '') {
		if(texture == null) texture = '';
		if(postfix == null) postfix = '';

		var skin:String = texture + postfix;
		if(texture.length < 1)
		{
			skin = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
			if(skin == null || skin.length < 1)
				skin = defaultNoteSkin + postfix;
		}
		else rgbShader.enabled = false;

		var animName:String = null;
		if(animation.curAnim != null) {
			animName = animation.curAnim.name;
		}

		var lastScaleY:Float = scale.y;
		colorSkinImage = NoteSkinData.resolveImage(skin);
		var config = NoteSkinData.load(colorSkinImage, isSustainNote ? 'sustains' : 'notes');
		var alternate = texture.length == 0 && noteType != 'Hurt Note' && rgbShader.allowNew
			? config.defaultImage(PlayState.isPixelStage, isSustainNote) : null;
		usesDefaultColorsImage = alternate != null;
		rgbShader.textureAllowsRGB = !usesDefaultColorsImage;
		var image = usesDefaultColorsImage ? alternate
			: (PlayState.isPixelStage && isSustainNote ? NoteSkinData.pixelSustainImage(colorSkinImage) : colorSkinImage);

		pixelColumns = config.pixelColumns;
		if(PlayState.isPixelStage) {
			if(isSustainNote) {
				// ENDS is the sustain texture of this skin, not a separate skin.
				loadSkinData(colorSkinImage, 'sustains');
				pixelColumns = skinData.pixelColumns;
				var graphic = Paths.image(image);
				loadGraphic(graphic, true, Math.floor(graphic.width / pixelColumns), Math.floor(graphic.height / 2));
				originalHeight = graphic.height / 2;
			} else {
				loadSkinData(colorSkinImage, 'notes');
				var graphic = Paths.image(image);
				loadGraphic(graphic, true, Math.floor(graphic.width / pixelColumns), Math.floor(graphic.height / 5));
			}
			setGraphicSize(Std.int(width * PlayState.daPixelZoom * KeyMode.scale(this.keyCount)));
			loadPixelNoteAnims();
			antialiasing = false;

		} else {
			loadSkinData(colorSkinImage, isSustainNote ? 'sustains' : 'notes');
			frames = Paths.getSparrowAtlas(image);
			sustainHeadFrameWidth = frameWidth;
			loadNoteAnims();
			if(!isSustainNote)
			{
				centerOffsets();
				centerOrigin();
			}
		}
		if (PlayState.isPixelStage && isSustainNote)
		{
			// Both values are unscaled grid-cell widths. Do not apply pixel zoom twice.
			var headImage = usesDefaultColorsImage ? config.defaultImage(true) : null;
			var headWidth = Math.floor(Paths.image(headImage != null ? headImage : colorSkinImage).width / config.pixelColumns);
			offsetX += _lastNoteOffX;
			_lastNoteOffX = (frameWidth - headWidth) * (PlayState.daPixelZoom * KeyMode.scale(keyCount) / 2);
			offsetX -= _lastNoteOffX;
		}

		if(isSustainNote) {
			scale.y = lastScaleY;
		}
		updateHitbox();

		if(animName != null)
			animation.play(animName, true);
	}

	public function refreshColors(previous:Array<FlxColor>):Void
	{
		rgbShader.refreshColors(previous, NoteSkinData.getColors(null, colorSkinImage)[noteStyle]);
	}

	public function refreshSkin()
	{
		// A script's unchanged texture may deliberately use a different logical
		// size/offset from its drawing scale. A palette change must not reset it.
		if (texture != null && texture.length > 0 && NoteSkinData.resolveImage(texture) == colorSkinImage) return;
		var rgbEnabled:Bool = rgbShader.enabled;
		var scaleX:Float = scale.x;
		var scaleY:Float = scale.y;
		var previousOffsetX:Float = offsetX;
		var previousFrameWidth:Int = frameWidth;
		var previousFrameHeight:Int = frameHeight;
		var previousSustainCenter:Float = (sustainHeadFrameWidth - frameWidth) * Math.abs(scaleX) / 2;
		var sustainHeight:Float = frameHeight * scaleY;
		reloadNote(texture);
		rgbShader.enabled = rgbEnabled;
		scale.set(scaleX, isSustainNote ? sustainHeight / frameHeight : scaleY);
		updateHitbox();
		if (isSustainNote && !PlayState.isPixelStage)
		{
			// Replace only the skin's centering contribution; retain offsets added by scripts.
			// Pixel sustains already replace their grid-based offset in reloadNote().
			offsetX += (sustainHeadFrameWidth - frameWidth) * Math.abs(scaleX) / 2 - previousSustainCenter;
		}
		// Options can close while gameplay is still paused. Apply the offset delta
		// now, without waiting for followStrumNote or replacing script-owned positions.
		if (isSustainNote && copyX) x += offsetX - previousOffsetX;
		if (isSustainNote && clipRect != null)
		{
			// Keep the already-consumed portion in the new atlas's coordinates,
			// without waiting for the next gameplay clipping pass.
			var ratioX:Float = frameWidth / previousFrameWidth;
			var ratioY:Float = frameHeight / previousFrameHeight;
			clipRect.set(clipRect.x * ratioX, clipRect.y * ratioY, clipRect.width * ratioX, clipRect.height * ratioY);
			clipRect = clipRect;
		}
	}

	public static function getNoteSkinPostfix(?noteSkin:String)
	{
		if (noteSkin == null) noteSkin = ClientPrefs.data.noteSkin;
		var skin:String = '';
		if(noteSkin != ClientPrefs.defaultData.noteSkin)
			skin = '-' + noteSkin.trim().toLowerCase().replace(' ', '_');
		return skin;
	}

	function loadNoteAnims() {
		if (noteData < 0) return;
		if (isSustainNote)
		{
			NoteAnimations.add(this, animColor + 'holdend', noteStyle, 'end', 24, true);
			NoteAnimations.add(this, animColor + 'hold', noteStyle, 'hold', 24, true);
		}
		else NoteAnimations.add(this, animColor + 'Scroll', noteStyle, 'head');
		setGraphicSize(Std.int(width * 0.7 * KeyMode.scale(keyCount)));
		updateHitbox();
	}

	function loadPixelNoteAnims() {
		if (noteData < 0) return;
		var frame = NoteAnimations.pixelStyle(noteStyle, pixelColumns);
		if (isSustainNote)
		{
			animation.add(animColor + 'holdend', [frame + pixelColumns], 24, true);
			animation.add(animColor + 'hold', [frame], 24, true);
		}
		else animation.add(animColor + 'Scroll', [frame + pixelColumns], 24, true);
	}

	function attemptToAddAnimationByPrefix(name:String, prefix:String, framerate:Float = 24, doLoop:Bool = true)
	{
		var animFrames = [];
		@:privateAccess
		animation.findByPrefix(animFrames, prefix); // adds valid frames to animFrames
		if(animFrames.length < 1) return;

		animation.addByPrefix(name, prefix, framerate, doLoop);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult) &&
						strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult));

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = false;

			if (!wasGoodHit && strumTime <= Conductor.songPosition)
			{
				if(!isSustainNote || (prevNote.wasGoodHit && !ignoreNote))
					wasGoodHit = true;
			}
		}

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}

	public function followStrumNote(myStrum:StrumNote, fakeCrochet:Float, songSpeed:Float = 1)
	{
		var strumX:Float = myStrum.x;
		var strumY:Float = myStrum.y;
		var strumAngle:Float = myStrum.angle;
		var strumAlpha:Float = myStrum.alpha;
		var strumDirection:Float = myStrum.direction;

		distance = (0.45 * (Conductor.songPosition - strumTime) * songSpeed * multSpeed);
		if (!myStrum.downScroll) distance *= -1;

		var angleDir = strumDirection * Math.PI / 180;
		if (copyAngle)
			angle = strumDirection - 90 + strumAngle + offsetAngle;

		if(copyAlpha)
			alpha = strumAlpha * multAlpha;

		if(copyX)
			x = strumX + offsetX + Math.cos(angleDir) * distance;

		if(copyY)
		{
			y = strumY + offsetY + correctionOffset + Math.sin(angleDir) * distance;
			if(myStrum.downScroll && isSustainNote)
			{
				if(PlayState.isPixelStage)
				{
					y -= PlayState.daPixelZoom * KeyMode.scale(keyCount) * 9.5;
				}
				y -= (frameHeight * scale.y) - (myStrum.height / 2);
			}
		}
	}

	public function clipToStrumNote(myStrum:StrumNote)
	{
		var center:Float = myStrum.y + offsetY + myStrum.height / 2;
		if((mustPress || !ignoreNote) && (wasGoodHit || (prevNote.wasGoodHit && !canBeHit)))
		{
			var swagRect:FlxRect = clipRect;
			if(swagRect == null) swagRect = new FlxRect(0, 0, frameWidth, frameHeight);

			if (myStrum.downScroll)
			{
				if(y - offset.y * scale.y + height >= center)
				{
					swagRect.width = frameWidth;
					swagRect.height = (center - y) / scale.y;
					swagRect.y = frameHeight - swagRect.height;
				}
			}
			else if (y + offset.y * scale.y <= center)
			{
				swagRect.y = (center - y) / scale.y;
				swagRect.width = width / scale.x;
				swagRect.height = (height / scale.y) - swagRect.y;
			}
			clipRect = swagRect;
		}
	}

	@:noCompletion
	override function set_clipRect(rect:FlxRect):FlxRect
	{
		clipRect = rect;

		if (frames != null)
			frame = frames.frames[animation.frameIndex];

		return rect;
	}
}
