package objects;

import flixel.addons.display.FlxPieDial;

#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
import hxvlc.util.macros.Define;
#end

class VideoSprite extends FlxSpriteGroup {
	#if VIDEOS_ALLOWED
	public var finishCallback:Void->Void = null;
	public var onSkip:Void->Void = null;

	final _timeToSkip:Float = 1;
	public var holdingTime:Float = 0;
	public var videoSprite:FlxVideoSprite;
	public var skipSprite:FlxPieDial;
	public var cover:FlxSprite;
	public var canSkip(default, set):Bool = false;

	private var videoName:String;
	private var hasVideoFrame:Bool = false;

	public var waiting:Bool = false;

	public function new(videoName:String, isWaiting:Bool, canSkip:Bool = false, shouldLoop:Dynamic = false) {
		super();

		this.videoName = videoName;
		scrollFactor.set();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		waiting = isWaiting;
		if(!waiting)
		{
			cover = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			cover.scale.set(FlxG.width + 100, FlxG.height + 100);
			cover.screenCenter();
			cover.scrollFactor.set();
			add(cover);
		}

		// initialize sprites
		videoSprite = new FlxVideoSprite();
		videoSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(videoSprite);
		if(canSkip) this.canSkip = true;

		// callbacks
		if(!shouldLoop) videoSprite.bitmap.onEndReached.add(finishVideo);
		videoSprite.bitmap.onDisplay.add(function()
		{
			if(!alreadyDestroyed) hasVideoFrame = true;
		}, true);

		videoSprite.bitmap.onFormatSetup.add(function()
		{
			if(alreadyDestroyed) return;
			videoSprite.setGraphicSize(FlxG.width);
			videoSprite.updateHitbox();
			videoSprite.screenCenter();
		});

		// start video and adjust resolution to screen size
		videoSprite.load(videoName, shouldLoop ? ['input-repeat=65545'] : null);
		syncVolume();
	}

	var alreadyDestroyed:Bool = false;
	override function destroy()
	{
		if(alreadyDestroyed)
			return;
		alreadyDestroyed = true;
		hasVideoFrame = false;
		holdingTime = 0;

		// Native events may already be queued for the main thread.
		videoSprite.bitmap.onOpening.removeAll();
		videoSprite.bitmap.onFormatSetup.removeAll();
		videoSprite.bitmap.onDisplay.removeAll();
		videoSprite.bitmap.onEndReached.removeAll();

		trace('Video destroyed');
		if(cover != null)
		{
			remove(cover);
			cover.destroy();
		}
		
		finishCallback = null;
		onSkip = null;

		if(FlxG.state != null)
		{
			if(FlxG.state.members.contains(this))
				FlxG.state.remove(this);

			if(FlxG.state.subState != null && FlxG.state.subState.members.contains(this))
				FlxG.state.subState.remove(this);
		}
		super.destroy();
		videoSprite = null;
		skipSprite = null;
		cover = null;
	}
	function finishVideo()
	{
		completeVideo(false);
	}

	function completeVideo(skipped:Bool)
	{
		if(alreadyDestroyed) return;

		var callback = skipped ? onSkip : finishCallback;
		// A callback can change states, destroy this video or start another one.
		destroy();
		if(callback != null) callback();
	}

	override function update(elapsed:Float)
	{
		if(alreadyDestroyed) return;

		// Loading/preloaded videos must not consume the key used to enter the song.
		if(canSkip && hasVideoFrame && videoSprite.bitmap.isPlaying)
		{
			if(Controls.instance.pressed('accept'))
			{
				holdingTime = Math.max(0, Math.min(_timeToSkip, holdingTime + elapsed));
			}
			else if (holdingTime > 0)
			{
				holdingTime = Math.max(0, FlxMath.lerp(holdingTime, -0.1, FlxMath.bound(elapsed * 3, 0, 1)));
			}
			updateSkipAlpha();

			if(holdingTime >= _timeToSkip)
			{
				completeVideo(true);
				trace('Skipped video');
				return;
			}
		}
		else
		{
			holdingTime = 0;
			updateSkipAlpha();
		}
		super.update(elapsed);
	}

	function set_canSkip(newValue:Bool)
	{
		canSkip = newValue;
		holdingTime = 0;
		if(canSkip)
		{
			if(skipSprite == null)
			{
				skipSprite = new FlxPieDial(0, 0, 40, FlxColor.WHITE, 40, true, 24);
				skipSprite.replaceColor(FlxColor.BLACK, FlxColor.TRANSPARENT);
				skipSprite.x = FlxG.width - (skipSprite.width + 80);
				skipSprite.y = FlxG.height - (skipSprite.height + 72);
				skipSprite.amount = 0;
				skipSprite.alpha = 0;
				add(skipSprite);
			}
			updateSkipAlpha();
		}
		else if(skipSprite != null)
		{
			remove(skipSprite);
			skipSprite.destroy();
			skipSprite = null;
		}
		return canSkip;
	}

	function updateSkipAlpha()
	{
		if(skipSprite == null) return;

		skipSprite.amount = Math.min(1, Math.max(0, (holdingTime / _timeToSkip) * 1.025));
		skipSprite.alpha = FlxMath.remapToRange(skipSprite.amount, 0.025, 1, 0, 1);
	}

	function syncVolume()
	{
		// hxvlc's onOpening runs later; OpenAL can start playing before it arrives.
		var volume = FlxG.sound.muted ? 0 : FlxG.sound.volume;
		videoSprite.bitmap.volume = Math.floor(volume * Define.getFloat('HXVLC_FLIXEL_VOLUME_MULTIPLIER', 125) * videoSprite.volumeAdjust);
	}

	public function play()
	{
		if(alreadyDestroyed) return;
		syncVolume();
		videoSprite.play();
	}

	public function resume()
	{
		if(alreadyDestroyed) return;
		syncVolume();
		videoSprite.resume();
	}
	public function pause() videoSprite?.pause();
	#end
}
