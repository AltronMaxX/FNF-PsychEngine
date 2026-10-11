package backend;

/** Prefix fallbacks are resolved independently for heads, tails and receptors.
 * Match a complete prefix followed by frame digits, so LEFT never reads LEFT2. */
class NoteAnimations
{
	public static function prefix(sprite:FlxSprite, style:Int, kind:String):String
	{
		var current = style;
		while (true)
		{
			var color = KeyMode.colors[current];
			var dir = KeyMode.directions[current];
			var names:Array<String> = switch (kind)
			{
				case 'head': [color];
				case 'hold': [color + ' hold piece'];
				case 'end': current == 0 ? ['purple hold end', 'pruple end hold'] : [color + ' hold end'];
				case 'static': ['arrow' + dir];
				default: [dir.toLowerCase() + ' ' + kind];
			};
			// Also accept the correctly spelled diamond name and EK+'s SPACE name.
			if (current == 4)
				for (name in names.copy())
				{
					names.push(name.replace('ROMBUS', 'DIAMOND').replace('rombus', 'diamond'));
					names.push(name.replace('ROMBUS', 'SPACE').replace('rombus', 'space'));
				}
			for (name in names)
				if (frames(sprite, name).length > 0) return name;
			if (current < 4) return names[0];
			current = KeyMode.fallback(current);
		}
	}
	static function frames(sprite:FlxSprite, prefix:String):Array<Int>
	{
		var found:Array<{index:Int, number:Int}> = [];
		if (sprite.frames != null)
			for (i => frame in sprite.frames.frames)
				if (frame.name != null && frame.name.startsWith(prefix))
				{
					var suffix = frame.name.substr(prefix.length);
					if (suffix == '' || (suffix.length <= 4 && ~/^[0-9]+$/.match(suffix)))
						found.push({index: i, number: suffix == '' ? 0 : Std.parseInt(suffix)});
				}
		found.sort((a, b) -> a.number - b.number);
		return [for (entry in found) entry.index];
	}
	public static function add(sprite:FlxSprite, name:String, style:Int, kind:String, fps:Float = 24, loop:Bool = false):Void
		sprite.animation.add(name, frames(sprite, prefix(sprite, style, kind)), fps, loop);

	/** Legacy pixel grids have 4 columns; EK grids have 6, extended skins 10.
	 * Metadata makes this explicit, avoiding guesses based on image dimensions. */
	public static function pixelStyle(style:Int, columns:Int):Int
	{
		if (columns >= 10) return style;
		if (style >= 5 && style <= 8) style -= 5;
		if (style == 9) style = columns >= 6 ? 5 : 4;
		if (style == 4 && columns < 5) style = 2;
		return style;
	}
}
