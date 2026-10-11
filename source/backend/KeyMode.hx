package backend;

/** Chart keys is the lane count (4 = 4K).
 * Lane counts and artwork identities are deliberately separate: future 10–18K
 * modes only need layouts and default bindings, not another input/render path. */
class KeyMode
{
	public static final layouts:Array<Array<Int>> = [
		[4], [0, 3], [0, 4, 3], [0, 1, 2, 3], [0, 1, 4, 2, 3],
		[0, 2, 3, 5, 1, 8], [0, 2, 3, 4, 5, 1, 8],
		[0, 1, 2, 3, 5, 6, 7, 8], [0, 1, 2, 3, 4, 5, 6, 7, 8]
	];
	public static final colors = ['purple', 'blue', 'green', 'red', 'rombus', 'purple2', 'blue2', 'green2', 'red2', 'circle'];
	public static final directions = ['LEFT', 'DOWN', 'UP', 'RIGHT', 'ROMBUS', 'LEFT2', 'DOWN2', 'UP2', 'RIGHT2', 'CIRCLE'];
	// Character poses are independent of artwork. Higher modes reuse circles for
	// different directions; add their per-lane poses here alongside their layouts.
	public static final singDirections:Array<Array<Int>> = [
		[2], [0, 3], [0, 2, 3], [0, 1, 2, 3], [0, 1, 2, 2, 3],
		[0, 2, 3, 0, 1, 3], [0, 2, 3, 2, 0, 1, 3],
		[0, 1, 2, 3, 0, 1, 2, 3], [0, 1, 2, 3, 2, 0, 1, 2, 3]
	];
	public static final defaultKeyboard:Array<Array<Int>> = [
		[32], [68, 75], [68, 32, 75], [65, 83, 87, 68],
		[68, 70, 32, 74, 75], [83, 68, 70, 74, 75, 76],
		[83, 68, 70, 32, 74, 75, 76], [65, 83, 68, 70, 72, 74, 75, 76],
		[65, 83, 68, 70, 32, 72, 74, 75, 76]
	];
	public static function normalize(value:Dynamic):Int
	{
		if (value == null || !Std.isOfType(value, Int)) return 4;
		var mode:Int = value;
		return mode >= 1 && mode <= layouts.length ? mode : 4;
	}
	public static function count(value:Dynamic):Int return normalize(value);
	public static function songKeys():Int return count(PlayState.SONG != null ? PlayState.SONG.keys : null);
	public static function style(keys:Int, lane:Int):Int
	{
		var layout = layouts[normalize(keys) - 1];
		return layout[(lane % layout.length + layout.length) % layout.length];
	}
	public static function fallback(style:Int):Int return style == 9 ? 4 : (style == 4 ? 2 : (style >= 5 ? style - 5 : style));
	public static function direction(style:Int):Int
	{
		while (style > 3) style = fallback(style);
		return style;
	}
	public static function action(keys:Int, lane:Int):String
		return keys == 4 ? ['note_left', 'note_down', 'note_up', 'note_right'][lane] : 'note_${keys}k_$lane';
	public static function actions(keys:Int):Array<String> return [for (i in 0...keys) action(keys, i)];
	public static function singDirection(keys:Int, lane:Int):Int
	{
		var poses = singDirections[normalize(keys) - 1];
		return poses[(lane % poses.length + poses.length) % poses.length];
	}
	/** Change the editor's column count without changing note ownership or silently
	 * dropping notes. Returns false if the smaller field has occupied extra lanes. */
	public static function remapChart(song:backend.Song.SwagSong, keys:Int):Bool
	{
		var oldKeys = count(song.keys);
		var newKeys = count(keys);
		for (section in song.notes) for (note in section.sectionNotes)
			if (note[1] >= 0 && note[1] % oldKeys >= newKeys) return false;
		for (section in song.notes) for (note in section.sectionNotes)
			if (note[1] >= 0) note[1] = (note[1] % oldKeys) + Std.int(note[1] / oldKeys) * newKeys;
		song.keys = normalize(keys);
		return true;
	}
	// Shaggy's 6K/7K/9K sizes, interpolated for 5K and 8K. Visual size and
	// column spacing are separate: dense fields can use larger, readable arrows.
	static final sizes:Array<Float> = [0.7, 0.7, 0.7, 0.7, 0.65, 0.6, 0.55, 0.5, 0.46];
	static final spaces:Array<Float> = [112, 112, 112, 112, 98, 84, 77, 70, 63];
	public static function scale(keys:Int):Float return sizes[normalize(keys) - 1] / 0.7;
	public static function spacing(keys:Int):Float return spaces[normalize(keys) - 1];
	/** Preserves the original 4K positions; every other field fits the same space. */
	public static function laneX(keys:Int, lane:Int, player:Int, middle:Bool, screenWidth:Float = 1280):Float
	{
		var step = spacing(keys);
		if (middle && player == 0)
		{
			var split = Std.int(Math.ceil(keys / 2));
			if (keys > 4)
				return lane < split ? 12 + lane * step : screenWidth - 12 - (keys - split) * step + (lane - split) * step;
			return lane < split ? 82 + lane * step : screenWidth - 309 + (lane - split) * step;
		}
		var center = middle ? screenWidth / 2 - 4 : screenWidth * (player == 0 ? 0.25 : 0.75) - 4;
		return center - keys * step / 2 + lane * step;
	}
}
