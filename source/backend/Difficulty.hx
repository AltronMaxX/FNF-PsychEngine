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
	private static var displayNames:Map<String, String> = [];

	// Keep chart identities in list/getString/getFilePath. Aliases are UI only.
	public static function loadDisplayNames(difficulties:String, displayedDifficulties:String):Void
	{
		displayNames.clear();
		if(displayedDifficulties == null) return;
		var names = difficulties != null && difficulties.trim().length > 0
			? difficulties.split(',') : vanillaList.copy();
		var displayed = displayedDifficulties.split(',');
		for(i in 0...names.length)
		{
			var name = names[i].trim().toLowerCase();
			if(name.length < 1 || displayNames.exists(name)) continue;
			// Do not remove empty slots: their positions correspond to difficulties.
			displayNames.set(name, i < displayed.length ? displayed[i].trim() : '');
		}
	}

	public static function loadDisplayFromSong(song:SongData):Void
	{
		if(song == null) displayNames.clear();
		else loadDisplayNames(song.difficulties, song.displayedDifficulties);
	}

	public static function loadDisplayForSong(songName:String, week:WeekData = null):Void
	{
		displayNames.clear();
		if(week == null) week = WeekData.getCurrentWeek();
		if(week == null || songName == null) return;
		for(song in week.songs)
		{
			if(Paths.formatToSongPath(song.songName) == Paths.formatToSongPath(songName))
			{
				loadDisplayFromSong(song);
				return;
			}
		}
	}

	public static function getDisplayString(?num:Null<Int> = null, ?canTranslate:Bool = true):String
	{
		var name = getString(num, false);
		var displayed = displayNames.get(name.trim().toLowerCase());
		if(displayed == null || displayed.length == 0) return getString(num, canTranslate);
		return canTranslate ? Language.getPhrase('difficulty_$displayed', displayed) : displayed;
	}

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
		loadDisplayNames(week.difficulties, week.displayedDifficulties);
		var allowed = week.difficulties != null && week.difficulties.trim().length > 0
			? week.difficulties.split(',').map(diff -> diff.trim()) : vanillaList.copy();
		list = [];
		for(diff in allowed)
		{
			if(diff.length < 1 || list.map(name -> name.toLowerCase()).contains(diff.toLowerCase())) continue;
			for(song in week.songs)
			{
				if(song.difficulties.split(',').map(name -> name.trim().toLowerCase()).contains(diff.toLowerCase()))
				{
					list.push(diff);
					break;
				}
			}
		}
	}

	inline public static function loadFromAllWeeks() {
		displayNames.clear();
		var diffs:Array<String> = [];
		for (w in WeekData.weeksList) {
			final week = WeekData.weeksLoaded.get(w);
			
			var diffStr:String = week.difficulties;
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
		}
		if(diffs.length > 0 && diffs[0].length > 0)
			list = diffs;

		if (list == [])
			resetList();
	}

	inline public static function resetList()
	{
		displayNames.clear();
		list = vanillaList.copy();
	}

	inline public static function copyFrom(diffs:Array<String>)
	{
		displayNames.clear();
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
