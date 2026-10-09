package objects;

import backend.animation.PsychAnimationController;
import backend.NoteSkinData;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;

class StrumNote extends NoteSkinSprite
{
	public var rgbShader:RGBShaderReference;
	public var colorSkinImage(default, null):String;
	public var usesDefaultColorsImage(default, null):Bool = false;
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;
	public var direction:Float = 90;
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;
	private var player:Int;
	var baseFrameWidth:Float = 0;
	var baseFrameHeight:Float = 0;
	
	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	public var useRGBShader:Bool = true;
	public function new(x:Float, y:Float, leData:Int, player:Int) {
		animation = new PsychAnimationController(this);

		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(leData));
		rgbShader.enabled = false;
		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;
		
		var arr:Array<FlxColor> = NoteSkinData.getColors()[leData];
		
		if(leData <= arr.length)
		{
			@:bypassAccessor
			{
				rgbShader.r = arr[0];
				rgbShader.g = arr[1];
				rgbShader.b = arr[2];
			}
		}

		noteData = leData;
		this.player = player;
		this.noteData = leData;
		super(x, y);
		this.ID = noteData;

		texture = getDefaultTexture();
		scrollFactor.set();
		playAnim('static');
	}

	public static function getDefaultTexture(?noteSkin:String):String
	{
		var image = NoteSkinData.resolveImage(null, null, noteSkin);
		return image.startsWith('pixelUI/') ? image.substr(8) : image;
	}

	public function refreshSkin(previousSkin:String)
	{
		if (texture != getDefaultTexture(previousSkin)) return;
		var rgbEnabled:Bool = rgbShader.enabled;
		var scaleX:Float = scale.x;
		var scaleY:Float = scale.y;
		@:bypassAccessor texture = getDefaultTexture();
		reloadNote();
		rgbShader.enabled = rgbEnabled;
		scale.set(scaleX, scaleY);
		updateHitbox();
	}

	public function reloadNote()
	{
		var previousAnim = animation.curAnim;
		var lastAnim = previousAnim != null ? previousAnim.name : null;
		var lastFrame = previousAnim != null ? previousAnim.curFrame : 0;
		var wasFinished = previousAnim != null && previousAnim.finished;
		var wasPaused = previousAnim != null && previousAnim.paused;
		var frameTimer:Float = previousAnim != null ? @:privateAccess previousAnim._frameTimer : 0;
		baseFrameWidth = baseFrameHeight = 0;
		colorSkinImage = (PlayState.isPixelStage ? 'pixelUI/' : '') + texture;
		loadSkinData(colorSkinImage, 'strums');
		var alternate = rgbShader.allowNew ? skinData.defaultImage(PlayState.isPixelStage) : null;
		usesDefaultColorsImage = alternate != null;
		rgbShader.textureAllowsRGB = !usesDefaultColorsImage;
		var image = usesDefaultColorsImage ? alternate : colorSkinImage;
		if(PlayState.isPixelStage)
		{
			loadGraphic(Paths.image(image));
			width = width / 4;
			height = height / 5;
			loadGraphic(Paths.image(image), true, Math.floor(width), Math.floor(height));
			baseFrameWidth = frameWidth;
			baseFrameHeight = frameHeight;

			antialiasing = false;
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));

			animation.add('green', [6]);
			animation.add('red', [7]);
			animation.add('blue', [5]);
			animation.add('purple', [4]);
			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.add('static', [0]);
					animation.add('pressed', [4, 8], 12, false);
					animation.add('confirm', [12, 16], 24, false);
				case 1:
					animation.add('static', [1]);
					animation.add('pressed', [5, 9], 12, false);
					animation.add('confirm', [13, 17], 24, false);
				case 2:
					animation.add('static', [2]);
					animation.add('pressed', [6, 10], 12, false);
					animation.add('confirm', [14, 18], 12, false);
				case 3:
					animation.add('static', [3]);
					animation.add('pressed', [7, 11], 12, false);
					animation.add('confirm', [15, 19], 24, false);
			}
		}
		else
		{
			frames = Paths.getSparrowAtlas(image);
			baseFrameWidth = frameWidth;
			baseFrameHeight = frameHeight;
			animation.addByPrefix('green', 'arrowUP');
			animation.addByPrefix('blue', 'arrowDOWN');
			animation.addByPrefix('purple', 'arrowLEFT');
			animation.addByPrefix('red', 'arrowRIGHT');

			antialiasing = !PlayState.isPixelStage && ClientPrefs.data.antialiasing;
			setGraphicSize(Std.int(width * (PlayState.isPixelStage ? PlayState.daPixelZoom : 0.7)));

			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.addByPrefix('static', 'arrowLEFT');
					animation.addByPrefix('pressed', 'left press', PlayState.isPixelStage ? 12 : 24, false);
					animation.addByPrefix('confirm', 'left confirm', 24, false);
				case 1:
					animation.addByPrefix('static', 'arrowDOWN');
					animation.addByPrefix('pressed', 'down press', PlayState.isPixelStage ? 12 : 24, false);
					animation.addByPrefix('confirm', 'down confirm', 24, false);
				case 2:
					animation.addByPrefix('static', 'arrowUP');
					animation.addByPrefix('pressed', 'up press', PlayState.isPixelStage ? 12 : 24, false);
					animation.addByPrefix('confirm', 'up confirm', PlayState.isPixelStage ? 12 : 24, false);
				case 3:
					animation.addByPrefix('static', 'arrowRIGHT');
					animation.addByPrefix('pressed', 'right press', PlayState.isPixelStage ? 12 : 24, false);
					animation.addByPrefix('confirm', 'right confirm', 24, false);
			}
		}
		updateHitbox();

		if(lastAnim != null)
		{
			playAnim(lastAnim, true);
			animation.curAnim.curFrame = wasFinished ? animation.curAnim.numFrames - 1 : Std.int(Math.min(lastFrame, animation.curAnim.numFrames - 1));
			animation.curAnim.paused = wasPaused;
			@:privateAccess animation.curAnim.finished = wasFinished;
			@:privateAccess animation.curAnim._frameTimer = frameTimer;
			centerOffsets();
			centerOrigin();
		}
	}

	/** Confirm frames include a larger glow canvas. They must not resize the
	 * receptor's body when options reload its texture midway through a hit. */
	override public function updateHitbox():Void
	{
		if (baseFrameWidth <= 0 || baseFrameHeight <= 0)
		{
			super.updateHitbox();
			return;
		}
		width = Math.abs(scale.x) * baseFrameWidth;
		height = Math.abs(scale.y) * baseFrameHeight;
		centerOffsets();
		centerOrigin();
	}

	public function refreshColors(previous:Array<FlxColor>):Void
	{
		rgbShader.refreshColors(previous, NoteSkinData.getColors(null, colorSkinImage)[noteData]);
	}

	public function playerPosition()
	{
		x += Note.swagWidth * noteData;
		x += 50;
		x += ((FlxG.width / 2) * player);
	}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		if(animation.curAnim != null)
		{
			centerOffsets();
			centerOrigin();
		}
		rgbShader.enabled = useRGBShader && (animation.curAnim != null && animation.curAnim.name != 'static');
	}
}
