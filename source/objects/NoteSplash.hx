package objects;

import backend.animation.PsychAnimationController;
import backend.NoteSkinData;
import shaders.RGBPalette;
import flixel.system.FlxAssets.FlxShader;

typedef RGB = {
	r:Null<Int>,
	g:Null<Int>,
	b:Null<Int>
}

typedef NoteSplashAnim = {
	name:String,
	noteData:Int,
	prefix:String,
	indices:Array<Int>,
	offsets:Array<Float>,
	fps:Array<Int>
}

typedef NoteSplashConfig = {
	animations:Map<String, NoteSplashAnim>,
	scale:Float,
	allowRGB:Bool,
	allowPixel:Bool,
	rgb:Array<Null<RGB>>
}

class NoteSplash extends FlxSprite
{
	public var rgbShader:PixelSplashShaderRef;
	public var texture:String;
	public var config(default, set):NoteSplashConfig;
	public var babyArrow:StrumNote;
	public var noteData:Int = 0;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var inEditor:Bool = false;

	var spawned:Bool = false;
	var sourceNote:Note;
	var noteDataMap:Map<Int, String> = new Map();

	public static var defaultNoteSplash(default, never):String = "noteSplashes/noteSplashes";
	public static var configs:Map<String, NoteSplashConfig> = new Map();

	public function new(?x:Float = 0, ?y:Float = 0, ?splash:String)
	{
		super(x, y);

		animation = new PsychAnimationController(this);

		rgbShader = new PixelSplashShaderRef();
		shader = rgbShader.shader;

		loadSplash(splash);
	}

	public var maxAnims(default, set):Int = 0;
	public function loadSplash(?splash:String)
	{
		config = null;
		maxAnims = 0;

		if(splash == null)
		{
			splash = defaultNoteSplash + getSplashSkinPostfix();
			if (PlayState.SONG != null && PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) splash = PlayState.SONG.splashSkin;
		}

		texture = splash;
		frames = Paths.getSparrowAtlas(texture);
		if (frames == null)
		{
			texture = defaultNoteSplash + getSplashSkinPostfix();
			frames = Paths.getSparrowAtlas(texture);
			if (frames == null)
			{
				texture = defaultNoteSplash;
				frames = Paths.getSparrowAtlas(texture);
			}
		}

		var path:String = 'images/$texture';
		if (configs.exists(path))
		{
			this.config = configs.get(path);
			for (anim in this.config.animations)
			{
				if (anim.noteData % 4 == 0)
					maxAnims++;
			}
			return;
		}
		else if (Paths.fileExists('$path.json', TEXT))
		{
			var config:Dynamic = haxe.Json.parse(Paths.getTextFromFile('$path.json'));
			if (config != null)
			{
				var tempConfig:NoteSplashConfig = {
					animations: new Map(),
					scale: config.scale,
					allowRGB: config.allowRGB,
					allowPixel: config.allowPixel,
					rgb: config.rgb
				}

				for (i in Reflect.fields(config.animations))
				{
					var anim:NoteSplashAnim = Reflect.field(config.animations, i);
					tempConfig.animations.set(i, anim);
					if (anim.noteData % 4 == 0)
						maxAnims++;
				}

				this.config = tempConfig;
				configs.set(path, this.config);
				return;
			}
		}

		// Splashes with no json
		var tempConfig:NoteSplashConfig = createConfig();
		var anim:String = 'note splash';
		var fps:Array<Null<Int>> = [22, 26];
		var offsets:Array<Array<Float>> = [[0, 0]];
		if (Paths.fileExists('$path.txt', TEXT)) // Backwards compatibility with 0.7 splash txts
		{
			var configFile:Array<String> = CoolUtil.listFromString(Paths.getTextFromFile('$path.txt'));
			if (configFile.length > 0)
			{
				anim = configFile[0];
				if (configFile.length > 1)
				{
					var framerates:Array<String> = configFile[1].split(' ');
					fps = [Std.parseInt(framerates[0]), Std.parseInt(framerates[1])];
					if (fps[0] == null) fps[0] = 22;
					if (fps[1] == null) fps[1] = 26;

					if (configFile.length > 2)
					{
						offsets = [];
						for (i in 2...configFile.length)
						{
							if (configFile[i].trim() != '')
							{
								var animOffs:Array<String> = configFile[i].split(' ');
								var x:Float = Std.parseFloat(animOffs[0]);
								var y:Float = Std.parseFloat(animOffs[1]);
								if (Math.isNaN(x)) x = 0;
								if (Math.isNaN(y)) y = 0;
								offsets.push([x, y]);
							}
						}
					}
				}
			}
		}

		var failedToFind:Bool = false;
		while (true)
		{
			for (v in Note.colArray)
			{
				if (!checkForAnim('$anim $v ${maxAnims+1}'))
				{
					failedToFind = true;
					break;
				}
			}
			if (failedToFind) break;
			maxAnims++;
		}

		for (animNum in 0...maxAnims)
		{
			for (i => col in Note.colArray)
			{
				var data:Int = i % Note.colArray.length + (animNum * Note.colArray.length);
				var name:String = animNum > 0 ? '$col' + (animNum + 1) : col;
				var offset:Array<Float> = offsets[FlxMath.wrap(data, 0, Std.int(offsets.length-1))];
				addAnimationToConfig(tempConfig, 1, name, '$anim $col ${animNum + 1}', fps, offset, [], data);
			}
		}

		this.config = tempConfig;
		configs.set(path, this.config);
	}

	public function spawnSplashNote(?x:Float = 0, ?y:Float = 0, ?noteData:Int = 0, ?note:Note, ?randomize:Bool = true)
	{
		if (note != null && note.noteSplashData.disabled)
			return;

		aliveTime = 0;

		if (!inEditor)
		{
			var loadedTexture:String = resolveTexture(note);

			if (texture != loadedTexture) loadSplash(loadedTexture);
		}

		setPosition(x, y);

		if (babyArrow != null)
			setPosition(babyArrow.x - Note.swagWidth * 0.95, babyArrow.y - Note.swagWidth); // To prevent it from being misplaced for one game tick

		if (note != null)
			noteData = note.noteData;

		if (randomize && maxAnims > 1)
			noteData = noteData % Note.colArray.length + (FlxG.random.int(0, maxAnims - 1) * Note.colArray.length);

		this.noteData = noteData;
		var anim:String = playDefaultAnim();

		sourceNote = note;
		refreshColors();

		offset.set(10, 10);
		var conf:NoteSplashAnim = config.animations.get(anim);
		var offsets:Array<Float> = [0, 0];
		if (conf != null) offsets = conf.offsets;
		if (offsets != null)
		{
			offset.x += offsets[0];
			offset.y += offsets[1];
		}

		animation.finishCallback = function(name:String) {
			kill();
			spawned = false;
		}

		alpha = ClientPrefs.data.splashAlpha;
		if (note != null) alpha = note.noteSplashData.a;

		antialiasing = ClientPrefs.data.antialiasing;
		if (note != null) antialiasing = note.noteSplashData.antialiasing;
		if (PlayState.isPixelStage && config.allowPixel) antialiasing = false;

		var minFps:Int = 22;
		var maxFps:Int = 26;
		if (conf != null)
		{
			minFps = conf.fps[0];
			if (minFps < 0) minFps = 0;

			maxFps = conf.fps[1];
			if (maxFps < 0) maxFps = 0;
		}

		if (animation.curAnim != null)
			animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);

		spawned = true;
	}

	function resolveTexture(note:Note):String
	{
		if (note != null && note.noteSplashData.texture != null && note.noteSplashData.texture.length > 0)
			return note.noteSplashData.texture;
		if (PlayState.SONG != null && PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0)
			return PlayState.SONG.splashSkin;
		return defaultNoteSplash + getSplashSkinPostfix();
	}

	/** Replace a paused effect's skin at the same point in its animation. */
	public function refreshSkin():Void
	{
		if (inEditor) return;
		var image = resolveTexture(sourceNote);
		if (texture == image) return;
		var oldAnim = animation.curAnim;
		var phase:Float = oldAnim != null ? (oldAnim.curFrame + @:privateAccess oldAnim._frameTimer * oldAnim.frameRate) / oldAnim.numFrames : 0;
		var oldConfig = oldAnim != null ? config.animations.get(oldAnim.name) : null;
		var oldOffsets = oldConfig != null && oldConfig.offsets != null ? oldConfig.offsets : [0.0, 0.0];
		var extraX = offset.x - 10 - oldOffsets[0];
		var extraY = offset.y - 10 - oldOffsets[1];
		var scaleX = scale.x / config.scale;
		var scaleY = scale.y / config.scale;
		var data = noteData;
		loadSplash(image);
		noteData = maxAnims > 0 ? data % (maxAnims * Note.colArray.length) : data % Note.colArray.length;
		var animName = playDefaultAnim();
		var conf = config.animations.get(animName);
		var offsets = conf != null && conf.offsets != null ? conf.offsets : [0.0, 0.0];
		scale.set(scaleX * config.scale, scaleY * config.scale);
		offset.set(10 + offsets[0] + extraX, 10 + offsets[1] + extraY);
		if (oldAnim != null && animation.curAnim != null)
		{
			var anim = animation.curAnim;
			var frame = FlxMath.bound(phase * anim.numFrames, 0, anim.numFrames - 0.000001);
			anim.curFrame = Std.int(frame);
			anim.paused = oldAnim.paused;
			@:privateAccess anim._frameTimer = anim.frameRate > 0 ? (frame - anim.curFrame) / anim.frameRate : 0;
			@:privateAccess anim.finished = oldAnim.finished;
		}
		antialiasing = sourceNote != null ? sourceNote.noteSplashData.antialiasing : ClientPrefs.data.antialiasing;
		if (PlayState.isPixelStage && config.allowPixel) antialiasing = false;
	}

	public function refreshAlpha(previous:Float):Void
	{
		if (sourceNote != null && sourceNote.noteSplashData.a == previous)
			sourceNote.noteSplashData.a = ClientPrefs.data.splashAlpha;
		if (alpha == previous && (sourceNote == null || sourceNote.noteSplashData.a == ClientPrefs.data.splashAlpha))
			alpha = ClientPrefs.data.splashAlpha;
	}

	/** Retint an existing splash without restarting its animation. */
	public function refreshColors():Void
	{
		var note = sourceNote;
		// A hit head may already have been removed; its default skin no longer updates.
		var image = note != null && note.texture != null && note.texture.length > 0 ? note.colorSkinImage
			: (babyArrow != null ? babyArrow.colorSkinImage : NoteSkinData.resolveImage());
		var tempShader:RGBPalette = null;
		if (config.allowRGB)
		{
			Note.initializeGlobalRGBShader(noteData % Note.colArray.length);
			if (inEditor || (note == null || note.noteSplashData.useRGBShader) && (PlayState.SONG == null || !PlayState.SONG.disableNoteRGB))
			{
				tempShader = new RGBPalette();
				// If Note RGB is enabled:
				if ((note == null || !note.noteSplashData.useGlobalShader) || inEditor)
				{
					var colors = config.rgb;
					if (colors != null)
					{
						for (i in 0...colors.length)
						{
							if (i > 2) break;

							var arr = NoteSkinData.getColors(null, image)[noteData % Note.colArray.length];

							var rgb = colors[i];
							if (rgb == null)
							{
								if (i == 0) tempShader.r = arr[0];
								else if (i == 1) tempShader.g = arr[1];
								else if (i == 2) tempShader.b = arr[2];
								continue;
							}

							var r:Null<Int> = rgb.r;
							var g:Null<Int> = rgb.g;
							var b:Null<Int> = rgb.b;

							if (r == null || Math.isNaN(r) || r < 0) r = arr[i].red;
							if (g == null || Math.isNaN(g) || g < 0) g = arr[i].green;
							if (b == null || Math.isNaN(b) || b < 0) b = arr[i].blue;

							var color:FlxColor = FlxColor.fromRGB(r, g, b);
							if (i == 0) tempShader.r = color;
							else if (i == 1) tempShader.g = color;
							else if (i == 2) tempShader.b = color;
						}
					}
					else tempShader.copyValues(Note.globalRgbShaders[noteData % Note.colArray.length]);

					if (note != null)
					{
						if (note.noteSplashData.r != -1) tempShader.r = note.noteSplashData.r;
						if (note.noteSplashData.g != -1) tempShader.g = note.noteSplashData.g;
						if (note.noteSplashData.b != -1) tempShader.b = note.noteSplashData.b;
					}
				}
				else tempShader.copyValues(Note.globalRgbShaders[noteData % Note.colArray.length]);
			}
		}
		rgbShader.copyValues(tempShader);
		if (!config.allowPixel) rgbShader.pixelAmount = 1;
		else if (PlayState.isPixelStage) rgbShader.pixelAmount = 6;
	}

	public function playDefaultAnim()
	{
		var anim:String = noteDataMap.get(noteData);
		if (anim != null && animation.exists(anim))
			animation.play(anim, true);

		return anim;
	}

	function checkForAnim(anim:String)
	{
		var animFrames = [];
		@:privateAccess
		animation.findByPrefix(animFrames, anim); // adds valid frames to animFrames

		return animFrames.length > 0;
	}

	var aliveTime:Float = 0;
	static var buggedKillTime:Float = 0.5; //automatically kills note splashes if they break to prevent it from flooding your HUD
	override function update(elapsed:Float)
	{
		if (spawned)
		{
			aliveTime += elapsed;
			if (animation.curAnim == null && aliveTime >= buggedKillTime)
			{
				kill();
				spawned = false;
			}
		}

		if (babyArrow != null)
		{
			if (copyX)
				x = babyArrow.x - Note.swagWidth * 0.95;

			if (copyY)
				y = babyArrow.y - Note.swagWidth;
		}
		super.update(elapsed);
	}

	public static function getSplashSkinPostfix()
	{
		var skin:String = '';
		if (ClientPrefs.data.splashSkin != ClientPrefs.defaultData.splashSkin)
			skin = '-' + ClientPrefs.data.splashSkin.trim().toLowerCase().replace(' ', '-');
		return skin;
	}

	public static function createConfig():NoteSplashConfig
	{
		return {
			animations: new Map(),
			scale: 1,
			allowRGB: true,
			allowPixel: true,
			rgb: null
		}
	}

	public static function addAnimationToConfig(config:NoteSplashConfig, scale:Float, name:String, prefix:String, fps:Array<Int>, offsets:Array<Float>, indices:Array<Int>, noteData:Int):NoteSplashConfig
	{
		if (config == null) config = createConfig();

		config.animations.set(name, {name: name, noteData: noteData, prefix: prefix, indices: indices, offsets: offsets, fps: fps});
		config.scale = scale;
		return config;
	}

	function set_config(value:NoteSplashConfig):NoteSplashConfig
	{
		if (value == null) value = createConfig();

		@:privateAccess
		animation.clearAnimations();
		noteDataMap.clear();

		for (i in value.animations)
		{
			var key:String = i.name;
			if (i.prefix.length > 0 && key != null && key.length > 0)
			{
				if (i.indices != null && i.indices.length > 0)
					animation.addByIndices(key, i.prefix, i.indices, "", i.fps[1], false);
				else
					animation.addByPrefix(key, i.prefix, i.fps[1], false);

				noteDataMap.set(i.noteData, key);
			}
		}

		scale.set(value.scale, value.scale);
		return config = value;
	}

	function set_maxAnims(value:Int)
	{
		if (value > 0)
			noteData = Std.int(FlxMath.wrap(noteData, 0, (value * Note.colArray.length) - 1));
		else
			noteData = 0;

		return maxAnims = value;
	}
}

class NoteHoldCover extends FlxSprite
{
	public var rgbShader:RGBPalette;
	public var babyArrow:StrumNote;
	public var note:Note;
	public var inEditor:Bool = false;
	public var ending(default, null):Bool = false;
	var endTime:Float;
	var previewTime:Float;
	var pixel:Bool;
	var texture:String;

	public function new()
	{
		super();
		rgbShader = new RGBPalette();
		shader = rgbShader.shader;
		scrollFactor.set();
		animation.finishCallback = function(name:String)
		{
			if (name == 'start') animation.play('hold', true);
			else if (name == 'end') kill();
		};
	}

	public function start(arrow:StrumNote, ?source:Note)
	{
		revive();
		babyArrow = arrow;
		note = source;
		ending = false;
		previewTime = 0.8;
		endTime = source != null ? source.strumTime + source.sustainLength : 0;
		pixel = PlayState.isPixelStage;
		var path = getTexture(pixel);
		if (texture != path)
		{
			texture = path;
			frames = Paths.getSparrowAtlas(path);
			animation.addByPrefix('hold', 'hold', 24, true);
			animation.addByPrefix('end', 'end', 24, false);
			if (!pixel) animation.addByPrefix('start', 'start', 24, false);
		}
		// Pixel loop artwork is centered at (17, 19.5), inside the atlas trim (56, 10).
		// Keep the same anchor for the burst so switching animations does not move it.
		origin.set(pixel ? 73 : 162, pixel ? 29.5 : 150);
		offset.copyFrom(origin);
		antialiasing = !pixel && ClientPrefs.data.antialiasing;
		animation.play(pixel ? 'hold' : 'start', true);
		refreshAppearance();
	}

	public function advance(songPosition:Float, held:Bool)
	{
		if (ending || !alive) return;
		if (songPosition >= endTime)
		{
			if (note != null && note.mustPress) finishHold();
			else kill();
		}
		else if (!held) kill();
	}

	public function finishHold()
	{
		ending = true;
		animation.play('end', true);
		refreshAppearance();
	}

	public function refreshAppearance()
	{
		if (babyArrow == null) return;
		// The cover is always an RGB mask, including when the receptor uses its
		// baked default image. Its palette still follows that receptor and events.
		rgbShader.copyValues(babyArrow.rgbShader.parent);
		// R follows the receptor; the bright core remains white for any palette.
		rgbShader.g = FlxColor.WHITE;
		if (pixel) rgbShader.r = rgbShader.b = FlxColor.WHITE;
		setPosition(babyArrow.x + babyArrow.width / 2, babyArrow.y + babyArrow.height / 2);
		scale.set(babyArrow.scale.x / (pixel ? 1 : 0.7), babyArrow.scale.y / (pixel ? 1 : 0.7));
		angle = babyArrow.direction - 90;
		alpha = babyArrow.alpha * (ending ? ClientPrefs.data.holdSplashAlpha : ClientPrefs.data.holdCoverAlpha);
		visible = babyArrow.visible;
	}

	public static function getTexture(pixel:Bool):String
		return pixel ? 'pixelUI/holdCovers/noteHoldCover' : 'noteHoldCovers/noteHoldCover';

	override function update(elapsed:Float)
	{
		if (inEditor && !ending)
		{
			previewTime -= elapsed;
			if (previewTime <= 0) finishHold();
		}
		refreshAppearance();
		super.update(elapsed);
	}

	override public function kill()
	{
		super.kill();
		note = null;
		babyArrow = null;
	}
}

class PixelSplashShaderRef
{
	public var shader:PixelSplashShader = new PixelSplashShader();
	public var enabled(default, set):Bool = true;
	public var pixelAmount(default, set):Float = 1;

	public function copyValues(tempShader:RGBPalette)
	{
		if (tempShader != null)
		{
			for (i in 0...3)
			{
				shader.r.value[i] = tempShader.shader.r.value[i];
				shader.g.value[i] = tempShader.shader.g.value[i];
				shader.b.value[i] = tempShader.shader.b.value[i];
			}
			shader.mult.value[0] = tempShader.shader.mult.value[0];
		}
		else enabled = false;
	}

	public function set_enabled(value:Bool)
	{
		enabled = value;
		shader.mult.value = [value ? 1 : 0];
		return value;
	}

	public function set_pixelAmount(value:Float)
	{
		pixelAmount = value;
		shader.uBlocksize.value = [value, value];
		return value;
	}

	public function reset()
	{
		shader.r.value = [0, 0, 0];
		shader.g.value = [0, 0, 0];
		shader.b.value = [0, 0, 0];
	}

	public function new()
	{
		reset();
		enabled = true;

		if (!PlayState.isPixelStage) pixelAmount = 1;
		else pixelAmount = PlayState.daPixelZoom;
		//trace('Created shader ' + Conductor.songPosition);
	}
}

class PixelSplashShader extends FlxShader
{
	@:glFragmentHeader('
		#pragma header

		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;
		uniform vec2 uBlocksize;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec2 blocks = openfl_TextureSize / uBlocksize;
			vec4 color = flixel_texture2D(bitmap, floor(coord * blocks) / blocks);
			if (!hasTransform) {
				return color;
			}

			if (color.a == 0.0 || mult == 0.0) {
				return color * openfl_Alphav;
			}

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;

			color = mix(color, newColor, mult);

			if (color.a > 0.0) {
				return vec4(color.rgb, color.a);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}')

	@:glFragmentSource('
		#pragma header

		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')

	public function new()
	{
		super();
	}
}
