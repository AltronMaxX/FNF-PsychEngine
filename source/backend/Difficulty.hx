package backend;

import backend.WeekData.SongData;

class Difficulty
{
	public static final vanillaList:Array<String> = [
		'Easy',
		'Normal',
		'Hard'
	];

	public static final defaultList:Array<String> = [
		'Easy',
		'Normal',
		'Hard',
		'Erect',
		'Nightmare'
	];
	private static final defaultDifficulty:String = 'Normal'; //The chart that has no postfix and starting difficulty on Freeplay/Story Mode

	public static var list:Array<String> = [];

	inline public static function getFilePath(num:Null<Int> = null)
	{
		if(num == null) num = PlayState.storyDifficulty;

		var filePostfix:String = list[num];
		if(filePostfix != null && Paths.formatToSongPath(filePostfix) != Paths.formatToSongPath(defaultDifficulty))
			filePostfix = '-' + filePostfix;
		else
			filePostfix = '';
		return Paths.formatToSongPath(filePostfix);
	}

	inline public static function loadFromWeek(week:WeekData = null)
	{
		if(week == null) week = WeekData.getCurrentWeek();
		var diffs:Array<String> = [];

		var diffStr:String = week.difficulties;
		if(diffStr != null && diffStr.length > 0)
		{
			diffs = diffStr.trim().split(',');
			var i:Int = diffs.length - 1;
			while (i > 0)
			{
				if(diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if(diffs[i].length < 1) diffs.remove(diffs[i]);
				}
				--i;
			}
		}

		for (song in week.songs) { //parse from songs
			var diffStr:String = song.difficulties;
			if(diffStr != null && diffStr.length > 0)
			{
				var _diffs = diffStr.trim().split(',');
				var i:Int = _diffs.length - 1;
				while (i > 0)
				{
					if(_diffs[i] != null)
					{
						_diffs[i] = _diffs[i].trim();
						if(_diffs[i].length < 1) _diffs.remove(_diffs[i]);
					}
					--i;
				}

				for (diff in _diffs) {
					if (!diffs.contains(diff)) {
						diffs.push(diff);
					}
				}
			}
		}

		if(diffs.length > 0 && diffs[0].length > 0)
			list = diffs;

		if (list == [])
			resetList();
	}

	inline public static function resetList()
	{
		list = vanillaList.copy();
	}

	inline public static function copyFrom(diffs:Array<String>)
	{
		list = diffs.copy();
	}

	inline public static function getString(?num:Null<Int> = null, ?canTranslate:Bool = true):String
	{
		var diffName:String = list[num == null ? PlayState.storyDifficulty : num];
		if(diffName == null) diffName = defaultDifficulty;
		return canTranslate ? Language.getPhrase('difficulty_$diffName', diffName) : diffName;
	}

	inline public static function getDefault():String
	{
		return defaultDifficulty;
	}

	public static function getDiffID(diff:String):Int {
		diff = diff.trim().toLowerCase();
		for (i in 0...defaultList.length) {
			if (defaultList[i].toLowerCase() == diff) {
				return i;
			}
		}
		return -1; // this should not happen
	}
}