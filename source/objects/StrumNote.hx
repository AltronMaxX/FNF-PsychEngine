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
	public var noteData:Int = 0;
	public var keyCount:Int;
	public var styleOverride:Int = -1;
	public var noteStyle(get, never):Int;
	function get_noteStyle():Int return styleOverride >= 0 ? styleOverride : KeyMode.style(keyCount, noteData);
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
	public function new(x:Float, y:Float, leData:Int, player:Int, keyCount:Int = 0, styleOverride:Int = -1) {
		this.keyCount = keyCount > 0 ? keyCount : KeyMode.songKeys();
		this.styleOverride = styleOverride;
		this.noteData = leData;
		animation = new PsychAnimationController(this);

		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(noteStyle));
		rgbShader.enabled = false;
		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;
		
		var arr:Array<FlxColor> = NoteSkinData.getColors()[noteStyle];
		
		if(arr != null && arr.length == 3)
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
			var columns = skinData.pixelColumns;
			width = width / columns;
			height = height / 5;
			loadGraphic(Paths.image(image), true, Math.floor(width), Math.floor(height));
			baseFrameWidth = frameWidth;
			baseFrameHeight = frameHeight;

			antialiasing = false;
			setGraphicSize(Std.int(width * PlayState.daPixelZoom * KeyMode.scale(keyCount)));

			var frame = NoteAnimations.pixelStyle(noteStyle, columns);
			animation.add('static', [frame]);
			animation.add('pressed', [frame + columns, frame + columns * 2], 12, false);
			animation.add('confirm', [frame + columns * 3, frame + columns * 4], 24, false);
		}
		else
		{
			frames = Paths.getSparrowAtlas(image);
			baseFrameWidth = frameWidth;
			baseFrameHeight = frameHeight;
			for (i in 0...4) NoteAnimations.add(this, Note.colArray[i], i, 'static');
			antialiasing = ClientPrefs.data.antialiasing;
			setGraphicSize(Std.int(width * 0.7 * KeyMode.scale(keyCount)));
			NoteAnimations.add(this, 'static', noteStyle, 'static');
			NoteAnimations.add(this, 'pressed', noteStyle, 'press');
			NoteAnimations.add(this, 'confirm', noteStyle, 'confirm');
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
		rgbShader.refreshColors(previous, NoteSkinData.getColors(null, colorSkinImage)[noteStyle]);
	}

	public function playerPosition()
	{
		x = KeyMode.laneX(keyCount, noteData, player, ClientPrefs.data.middleScroll, FlxG.width, width);
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
