package objects;

import haxe.Json;
import openfl.utils.AssetType;

typedef HealthIconSettings = {
	var ?scale:Float;
	var ?offsets:Array<Float>;
	var ?flipX:Bool;
	var ?isPixel:Bool;
	var ?shouldBop:Bool;
}

class HealthIcon extends FlxSprite
{
	public static inline var ICON_SIZE:Int = 150;
	static final LOOP_ANIMATIONS:Array<String> = ['idle', 'losing', 'winning'];
	static final TRANSITION_ANIMATIONS:Array<String> = ['toLosing', 'fromLosing', 'toWinning', 'fromWinning'];

	public var sprTracker:FlxSprite;
	public var animated(default, null):Bool = false;
	public var autoUpdate:Bool = true;
	public var shouldBop:Bool = true;
	public var baseScale(default, null):Float = 1;
	public var scaleMultiplier(default, null):Float = 1;
	public var autoAdjustOffset:Bool = true;

	private var isPlayer:Bool = false;
	private var char:String = '';
	private var modDirectory:String = null;
	private var targetState:String = 'idle';
	private var iconOffsets:Array<Float> = [0, 0];
	private var customOffsets:Array<Float> = [0, 0];
	private var maxFrameWidth:Float = 0;
	private var maxFrameHeight:Float = 0;

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(autoUpdate && animated) updateState();
		// Sparrow frames can have different source sizes, including inside one animation.
		if(animated) updateHitbox();

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	/** Prefer an atlas over a legacy strip, including when the strip uses the other naming convention. */
	static function findIconKey(id:String):String
	{
		var keys = ['icons/icon-' + id, 'icons/' + id];
		for(key in keys)
			if(Paths.fileExists('images/$key.png', IMAGE) && Paths.fileExists('images/$key.xml', TEXT)) return key;
		// Retain Psych's priority between the two legacy names.
		keys.reverse();
		for(key in keys)
			if(Paths.fileExists('images/$key.png', IMAGE)) return key;
		return 'icons/icon-face';
	}

	public function changeIcon(char:String, ?allowGPU:Bool = true):Void
	{
		if(char == null || char.length == 0) char = 'face';
		if(this.char == char && modDirectory == Mods.currentModDirectory) return;
		this.char = char;
		modDirectory = Mods.currentModDirectory;
		var key = findIconKey(char);
		animated = Paths.fileExists('images/$key.xml', TEXT);
		baseScale = 1;
		shouldBop = true;
		customOffsets = [0, 0];
		maxFrameWidth = maxFrameHeight = 0;
		flipX = isPlayer;
		antialiasing = !char.endsWith('-pixel') && ClientPrefs.data.antialiasing;

		if(animated)
		{
			try
			{
				frames = Paths.getSparrowAtlas(key, null, allowGPU);
				if(frames == null || frames.numFrames == 0) throw 'Empty icon atlas';
				for(frame in frames.frames)
				{
					maxFrameWidth = Math.max(maxFrameWidth, frame.sourceSize.x);
					maxFrameHeight = Math.max(maxFrameHeight, frame.sourceSize.y);
				}
				baseScale = ICON_SIZE / Math.max(1, Math.max(maxFrameWidth, maxFrameHeight));
				for(name in LOOP_ANIMATIONS.concat(TRANSITION_ANIMATIONS))
				{
					if(frames.frames.filter(frame -> frame.name != null && frame.name.startsWith(name)).length > 0)
						animation.addByPrefix(name, name, 24, LOOP_ANIMATIONS.contains(name));
				}
				if(animation.getByName('idle') == null)
				{
					FlxG.log.warn('Health icon $char has no idle animation; using its first frame.');
					animation.add('idle', [0], 0, false);
				}
				animation.play('idle');
			}
			catch(error:Dynamic)
			{
				FlxG.log.warn('Invalid health icon $char: $error. Using face.');
				animated = false;
				key = 'icons/icon-face';
			}
		}
		if(!animated)
		{
			baseScale = 1;
			var graphic = Paths.image(key, null, allowGPU);
			var count = Std.int(Math.max(1, Math.round(graphic.width / graphic.height)));
			loadGraphic(graphic, true, Math.floor(graphic.width / count), graphic.height);
			maxFrameWidth = frameWidth;
			maxFrameHeight = frameHeight;
			iconOffsets[0] = (frameWidth - ICON_SIZE) / count;
			iconOffsets[1] = (frameHeight - ICON_SIZE) / count;
			// Preserve the animation name and frame indices exposed to old scripts.
			animation.add(char, [for(i in 0...frames.numFrames) i], 0, false);
			animation.play(char);
		}
		loadSettings(key);
		setScaleMultiplier(scaleMultiplier);
		setState(targetState);
	}

	function loadSettings(key:String):Void
	{
		var text = Paths.getTextFromFile('images/$key.json');
		if(text == null) return;
		try
		{
			var data:HealthIconSettings = Json.parse(text);
			if(data == null) return;
			if(data.scale != null && Math.isFinite(data.scale) && data.scale > 0) baseScale *= data.scale;
			if(data.offsets != null && data.offsets.length >= 2
				&& Math.isFinite(data.offsets[0]) && Math.isFinite(data.offsets[1]))
				customOffsets = [data.offsets[0], data.offsets[1]];
			flipX = isPlayer != (data.flipX == true);
			if(data.isPixel != null) antialiasing = !data.isPixel && ClientPrefs.data.antialiasing;
			if(data.shouldBop != null) shouldBop = data.shouldBop;
		}
		catch(error:Dynamic)
		{
			FlxG.log.warn('Invalid settings for health icon $char: $error');
		}
	}

	/** The percentage belongs to this icon's character, rather than always to the player. */
	public function setHealthPercent(percent:Float):Void
	{
		if(!autoUpdate) return;
		setState(percent < 20 ? 'losing' : (percent > 80 ? 'winning' : 'idle'));
	}

	public function setState(state:String):Void
	{
		if(!LOOP_ANIMATIONS.contains(state)) state = 'idle';
		targetState = state;
		if(animated)
			updateState();
		else if(animation.curAnim != null)
		{
			var frame = state == 'losing' ? 1 : (state == 'winning' ? 2 : 0);
			animation.curAnim.curFrame = frame < animation.curAnim.numFrames ? frame : 0;
		}
	}

	/** Transitions finish even when health is constant; repeated requests never restart them. */
	function updateState():Void
	{
		var current = animation.curAnim;
		if(current != null && TRANSITION_ANIMATIONS.contains(current.name))
		{
			if(!current.finished) return;
			switch(current.name)
			{
				case 'toLosing': playAnimation('losing', 'idle');
				case 'toWinning': playAnimation('winning', 'idle');
				default: playAnimation('idle');
			}
			return;
		}
		var target = animation.getByName(targetState) != null ? targetState : 'idle';
		var name = current != null ? current.name : '';
		if(name == target) return;
		switch(name)
		{
			case 'losing': playAnimation('fromLosing', 'idle');
			case 'winning': playAnimation('fromWinning', 'idle');
			default:
				switch(target)
				{
					case 'losing': playAnimation('toLosing', 'losing');
					case 'winning': playAnimation('toWinning', 'winning');
					default: playAnimation('idle');
				}
		}
	}

	public function playAnimation(name:String, ?fallback:String, restart:Bool = false):Void
	{
		if(animation.getByName(name) == null) name = fallback;
		if(name == null || animation.getByName(name) == null) name = 'idle';
		if(animation.getByName(name) != null) animation.play(name, restart);
		updateHitbox();
	}

	public function setScaleMultiplier(value:Float):Void
	{
		scaleMultiplier = value;
		scale.set(baseScale * value, baseScale * value);
		updateHitbox();
	}

	public function bop():Void
	{
		if(shouldBop) setScaleMultiplier(1.2);
	}

	/** Menus can reserve space for every pose instead of just the current idle frame. */
	public function getMaxWidth():Float
	{
		return maxFrameWidth * Math.abs(scale.x);
	}

	public function getMaxHeight():Float
	{
		return maxFrameHeight * Math.abs(scale.y);
	}

	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			// The logical center stays at (x + 75, y + 75), as expected by Psych HUD scripts.
			var dx = flipX ? -customOffsets[0] : customOffsets[0];
			offset.x = (animated ? (frameWidth - ICON_SIZE) / 2 : iconOffsets[0]) - dx;
			offset.y = (animated ? (frameHeight - ICON_SIZE) / 2 : iconOffsets[1]) - customOffsets[1];
		}
	}

	public function getCharacter():String {
		return char;
	}
}
