package backend;

import shaders.DiamondTransitionShader;

class CustomFadeTransition extends MusicBeatSubstate {
	public static var finishCallback:Void->Void;
	public static inline var DEFAULT_DURATION:Float = 0.5;
	public static inline var TILE_ANIMATION_DURATION:Float = 0.25;
	var isTransIn:Bool = false;
	var transitionCamera:FlxCamera;
	var transitionShader:DiamondTransitionShader;
	var elapsedTime:Float = 0;
	var finished:Bool = false;

	var duration:Float;
	public function new(duration:Float, isTransIn:Bool)
	{
		this.duration = duration;
		this.isTransIn = isTransIn;
		super();
	}

	override function create()
	{
		// Keep the wipe above every HUD/menu camera, unaffected by their zoom or filters.
		transitionCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height, 1);
		transitionCamera.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(transitionCamera, false);
		cameras = [transitionCamera];

		var tileDurationRatio:Float = duration > 0 ? Math.min(TILE_ANIMATION_DURATION / duration, 1) : 1;
		transitionShader = new DiamondTransitionShader(FlxG.width, FlxG.height, isTransIn, tileDurationRatio);
		var overlay = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		overlay.scale.set(FlxG.width, FlxG.height);
		overlay.updateHitbox();
		overlay.scrollFactor.set();
		overlay.shader = transitionShader;
		add(overlay);

		super.create();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if(finished) return;
		elapsedTime += elapsed;
		var progress:Float = duration > 0 ? Math.min(elapsedTime / duration, 1) : 1;
		// Each diamond changes size at a steady rate after its diagonal stagger delay.
		transitionShader.progress.value[0] = progress;
		if(progress >= 1) close();
	}

	// Don't delete this
	override function close():Void
	{
		if(finished) return;
		finished = true;
		var callback = finishCallback;
		finishCallback = null;
		super.close();

		if(callback != null) callback();
	}

	override function destroy():Void
	{
		super.destroy();
		// A state switch may already have reset (and destroyed) all cameras.
		if(transitionCamera != null && FlxG.cameras.list.contains(transitionCamera))
			FlxG.cameras.remove(transitionCamera);
		transitionCamera = null;
		transitionShader = null;
	}
}
