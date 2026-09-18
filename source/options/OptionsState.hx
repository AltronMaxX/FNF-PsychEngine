package options;

import flixel.FlxSubState;

class OptionsState extends MusicBeatState
{
	override function create()
	{
		var transitionIn:Bool = !FlxTransitionableState.skipNextTransOut;
		FlxTransitionableState.skipNextTransOut = true;
		super.create();
		add(OptionsSubState.createBackground());
		persistentUpdate = false;
		openSubState(new OptionsSubState(null, transitionIn));
	}

	override public function openSubState(nextSubState:FlxSubState):Void
	{
		if (subState != null && Std.isOfType(nextSubState, CustomFadeTransition))
		{
			var parent:FlxSubState = subState;
			while (parent.subState != null) parent = parent.subState;
			parent.openSubState(nextSubState);
		}
		else super.openSubState(nextSubState);
	}
}