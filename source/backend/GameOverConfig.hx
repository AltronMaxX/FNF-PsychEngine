package backend;

typedef GameOverSettings =
{
	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	@:optional var gameOverOnBeat:Null<Bool>;
	@:optional var gameOverBPM:Null<Float>;
	@:optional var gameOverFixOffsets:Null<Bool>;
	@:optional var gameOverCameraPosition:Array<Float>;
}

/** Optional JSON overrides shared by characters and charts. Null means inherit. */
class GameOverConfig
{
	public static final fields:Array<String> = ['gameOverChar', 'gameOverSound', 'gameOverLoop', 'gameOverEnd',
		'gameOverOnBeat', 'gameOverBPM', 'gameOverFixOffsets', 'gameOverCameraPosition'];

	public static function defaults():GameOverSettings
	{
		return {gameOverChar: 'bf-dead', gameOverSound: 'fnf_loss_sfx', gameOverLoop: 'gameOver',
			gameOverEnd: 'gameOverEnd', gameOverOnBeat: false, gameOverBPM: 100, gameOverFixOffsets: false,
			gameOverCameraPosition: [0, 0]};
	}

	public static function read(source:Dynamic):GameOverSettings
	{
		var result:GameOverSettings = {};
		if(source == null) return result;
		for(field in fields)
		{
			var value:Dynamic = Reflect.field(source, field);
			switch(field)
			{
				case 'gameOverCameraPosition':
					if(Std.isOfType(value, Array))
					{
						var position:Array<Dynamic> = value;
						if(position.length == 2 && isNumber(position[0]) && isNumber(position[1]))
							result.gameOverCameraPosition = [position[0], position[1]];
					}
				case 'gameOverOnBeat', 'gameOverFixOffsets':
					if(Std.isOfType(value, Bool)) Reflect.setField(result, field, value);
				case 'gameOverBPM':
					if(isNumber(value) && value > 0)
						Reflect.setField(result, field, value);
				default:
					if(Std.isOfType(value, String) && StringTools.trim(value).length > 0)
						Reflect.setField(result, field, StringTools.trim(value));
			}
		}
		return result;
	}

	static function isNumber(value:Dynamic):Bool
	{
		return (Std.isOfType(value, Float) || Std.isOfType(value, Int)) && Math.isFinite(value);
	}

	public static function apply(target:Dynamic, source:Dynamic):Void
	{
		var settings = read(source);
		for(field in Reflect.fields(settings)) Reflect.setField(target, field, Reflect.field(settings, field));
	}

	public static function resolve(character:Dynamic, chart:Dynamic):GameOverSettings
	{
		var result = defaults();
		apply(result, character);
		apply(result, chart);
		return result;
	}
}
