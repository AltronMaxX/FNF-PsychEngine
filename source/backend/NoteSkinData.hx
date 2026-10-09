package backend;

import haxe.Json;
import openfl.utils.Assets;

/** Skin transforms, default palettes and optional original-colour atlases. */
class NoteSkinData
{
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;
	public var alpha:Float = 1;
	public var angle:Float = 0;
	public var defaultColors:Array<Array<FlxColor>>;
	public var defaultColorsImage:String;
	public var defaultColorsEndsImage:String;

	static var cache:Map<String, Dynamic> = [];

	public function new() {}

	public static function clearCache():Void
		cache.clear();

	/** Logical RGB skin path, including pixelUI when appropriate. */
	public static function resolveImage(?base:String, ?pixel:Null<Bool>, ?noteSkin:String):String
	{
		if (pixel == null) pixel = PlayState.isPixelStage;
		if (base == null || base.length == 0)
			base = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
		if (base == null || base.length == 0) base = objects.Note.defaultNoteSkin;
		var path = (pixel ? 'pixelUI/' : '') + base;
		var custom = path + objects.Note.getNoteSkinPostfix(noteSkin);
		return Paths.fileExists('images/$custom.png', IMAGE) ? custom : path;
	}

	public static function usesCustomColors(?pixel:Null<Bool>):Bool
	{
		if (pixel == null) pixel = PlayState.isPixelStage;
		return pixel ? ClientPrefs.data.customNoteColorsPixel : ClientPrefs.data.customNoteColors;
	}

	public static function getColors(?pixel:Null<Bool>, ?image:String, defaultsOnly:Bool = false):Array<Array<FlxColor>>
	{
		if (pixel == null) pixel = PlayState.isPixelStage;
		if (!defaultsOnly && usesCustomColors(pixel))
			return pixel ? ClientPrefs.data.arrowRGBPixel : ClientPrefs.data.arrowRGB;
		if (image == null) image = resolveImage(null, pixel);
		var colors = load(image, 'notes').defaultColors;
		if (colors == null) colors = pixel ? ClientPrefs.defaultData.arrowRGBPixel : ClientPrefs.defaultData.arrowRGB;
		// Never let the editor mutate skin metadata or the engine defaults.
		return [for (row in colors) row.copy()];
	}

	public function defaultImage(pixel:Bool, sustain:Bool = false):String
	{
		var image = sustain && (pixel || defaultColorsEndsImage != null) ? defaultColorsEndsImage : defaultColorsImage;
		if (usesCustomColors(pixel) || image == null) return null;
		if (image.endsWith('.png')) image = image.substr(0, image.length - 4);
		if (!image.startsWith('noteSkins/')) image = 'noteSkins/' + image;
		if (pixel) image = 'pixelUI/' + image;
		// A typo or missing alternate should fall back to the RGB skin safely.
		if (!Paths.fileExists('images/$image.png', IMAGE) || (!pixel && !Paths.fileExists('images/$image.xml', TEXT))) return null;
		return image;
	}

	public static function pixelSustainImage(image:String):String
	{
		var slash = image.lastIndexOf('/') + 1;
		var dash = image.indexOf('-', slash);
		if (dash < 0) dash = image.length;
		return image.substr(0, dash) + 'ENDS' + image.substr(dash);
	}

	public static function parseColors(value:Dynamic):Array<Array<FlxColor>>
	{
		if (!Std.isOfType(value, Array)) return null;
		var rows:Array<Dynamic> = value;
		if (rows.length != 4) return null;
		var colors:Array<Array<FlxColor>> = [];
		for (row in rows)
		{
			if (!Std.isOfType(row, Array)) return null;
			var entries:Array<Dynamic> = row;
			if (entries.length != 3) return null;
			var parsed:Array<FlxColor> = [];
			for (entry in entries)
			{
				var color:Null<FlxColor> = null;
				if (Std.isOfType(entry, String)) color = FlxColor.fromString(entry);
				else if (Std.isOfType(entry, Array))
				{
					var rgb:Array<Dynamic> = entry;
					if (rgb.length != 3) return null;
					for (channel in rgb)
						if (!Std.isOfType(channel, Int) || channel < 0 || channel > 255) return null;
					color = FlxColor.fromRGB(rgb[0], rgb[1], rgb[2]);
				}
				if (color == null) return null;
				parsed.push(color | 0xFF000000);
			}
			colors.push(parsed);
		}
		return colors;
	}

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
		if (Reflect.hasField(data, 'defaultColors')) defaultColors = parseColors(data.defaultColors);
		if (Std.isOfType(data.defaultColorsImage, String) && StringTools.trim(data.defaultColorsImage).length > 0)
			defaultColorsImage = StringTools.trim(data.defaultColorsImage);
		if (Std.isOfType(data.defaultColorsEndsImage, String) && StringTools.trim(data.defaultColorsEndsImage).length > 0)
			defaultColorsEndsImage = StringTools.trim(data.defaultColorsEndsImage);
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
