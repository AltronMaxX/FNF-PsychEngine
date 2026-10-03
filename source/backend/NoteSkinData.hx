package backend;

import haxe.Json;
import openfl.utils.Assets;

/** Visual transforms for the actual image being loaded, independent of gameplay properties. */
class NoteSkinData
{
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;
	public var alpha:Float = 1;
	public var angle:Float = 0;

	static var cache:Map<String, Dynamic> = [];

	public function new() {}

	public static function clearCache():Void
		cache.clear();

	public static function load(image:String, kind:String):NoteSkinData
	{
		var path = Paths.getPath('images/$image.json', TEXT);
		if (!cache.exists(path))
		{
			var data:Dynamic = null;
			try
			{
				#if sys
				if (FileSystem.exists(path)) data = Json.parse(File.getContent(path));
				#else
				if (Assets.exists(path, TEXT)) data = Json.parse(Assets.getText(path));
				#end
			}
			catch (e:Dynamic) trace('Invalid note skin config "$path": $e');
			cache.set(path, data);
		}
		return fromJson(cache.get(path), kind);
	}

	public static function fromJson(data:Dynamic, kind:String):NoteSkinData
	{
		var result = new NoteSkinData();
		result.apply(data);
		if (isObject(data)) result.apply(Reflect.field(data, kind));
		return result;
	}

	static function isObject(value:Dynamic):Bool
		return value != null && Reflect.isObject(value) && !Std.isOfType(value, Array) && !Std.isOfType(value, String);

	static function number(value:Dynamic, fallback:Float):Float
	{
		if ((Std.isOfType(value, Float) || Std.isOfType(value, Int)) && Math.isFinite(value)) return value;
		return fallback;
	}

	function apply(data:Dynamic):Void
	{
		if (!isObject(data)) return;
		offsetX = number(data.offsetX, offsetX);
		offsetY = number(data.offsetY, offsetY);
		angle = number(data.angle, angle);
		alpha = FlxMath.bound(number(data.alpha, alpha), 0, 1);
		if (Std.isOfType(data.scale, Array))
		{
			var axes:Array<Dynamic> = data.scale;
			scaleX = number(axes[0], scaleX);
			scaleY = number(axes[1], scaleY);
		}
		else
		{
			scaleX = number(data.scale, scaleX);
			scaleY = number(data.scale, scaleY);
		}
	}
}
