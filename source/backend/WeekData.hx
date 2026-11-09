package backend;

import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import haxe.Json;

typedef WeekFile =
{
	// JSON variables
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	@:optional var showAfter:UnlockData;
	@:optional var unlockedAfter:UnlockData;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	@:optional var redirectToFreeplay:Bool;
	@:optional var freeplayCharacter:String;
	var difficulties:String;
	@:optional var displayedDifficulties:String;
}

typedef SongData = {
	@:optional
	var difficulties:String;
	@:optional
	var displayedDifficulties:String;
	var songName:String;
	var icon:String;
	var backgroundColor:Array<Int>;
	@:optional
	var unlockedAfter:UnlockData;
	@:optional
	var showAfter:UnlockData;
	// Controls the track list only; the song remains in the Story Mode playlist.
	@:optional
	var showInStoryMode:UnlockData;
	@:optional
	var linkedTo:String;
}

typedef UnlockData = {
	var save:String;
	var field:String;
};

class WeekData {
	public static var weeksLoaded:Map<String, WeekData> = new Map<String, WeekData>();
	public static var weeksList:Array<String> = [];
	public var folder:String = '';

	// JSON variables
	public var songs:Array<SongData>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var showAfter:UnlockData = null;
	public var unlockedAfter:UnlockData = null;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var redirectToFreeplay:Bool = false;
	public var freeplayCharacter:String = 'bf';
	public var difficulties:String;
	public var displayedDifficulties:String = null;

	public var fileName:String;

	public static function createWeekFile():WeekFile {
		var weekFile:WeekFile = {
			songs: [["Bopeebo", "face", [146, 113, 253]], ["Fresh", "face", [146, 113, 253]], ["Dad Battle", "face", [146, 113, 253]]],
			#if BASE_GAME_FILES
			weekCharacters: ['dad', 'bf', 'gf'],
			#else
			weekCharacters: ['bf', 'bf', 'gf'],
			#end
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			showAfter: null,
			unlockedAfter: null,
			hideStoryMode: false,
			hideFreeplay: false,
			redirectToFreeplay: false,
			freeplayCharacter: 'bf',
			difficulties: ''
		};
		return weekFile;
	}

	public static function prepareForSave(weekFile:WeekFile):WeekFile
	{
		var result:WeekFile = Reflect.copy(weekFile);
		result.songs = weekFile.songs.map(prepareSongForSave);
		if(result.redirectToFreeplay != true) Reflect.deleteField(result, 'redirectToFreeplay');
		if(isEmptyText(result.freeplayCharacter) || result.freeplayCharacter == 'bf')
			Reflect.deleteField(result, 'freeplayCharacter');
		if(isEmptyText(result.displayedDifficulties)) Reflect.deleteField(result, 'displayedDifficulties');
		removeEmptyUnlockConditions(result, ['showAfter', 'unlockedAfter']);
		return result;
	}

	static function prepareSongForSave(song:Dynamic):Dynamic
	{
		if(song == null) return null;
		if(Std.isOfType(song, Array))
		{
			var values:Array<Dynamic> = cast song;
			var result = values.copy();
			if(result.length == 4 && isUnlockConditionEmpty(getSongData(song).unlockedAfter)) result.pop();
			return result;
		}
		var result:SongData = getSongData(song);
		for(field in ['difficulties', 'displayedDifficulties', 'linkedTo'])
			if(isEmptyText(Reflect.field(result, field))) Reflect.deleteField(result, field);
		removeEmptyUnlockConditions(result, ['unlockedAfter', 'showAfter', 'showInStoryMode']);
		// Keep active extensions and unknown fields instead of losing their data.
		for(field in Reflect.fields(result))
			if(field != 'songName' && field != 'icon' && field != 'backgroundColor') return result;
		return [result.songName, result.icon, result.backgroundColor];
	}

	static function isEmptyText(value:Dynamic):Bool
		return value == null || (Std.isOfType(value, String) && StringTools.trim(value).length == 0);

	public static function createUnlockCondition(save:String, field:String):UnlockData
	{
		save = save != null ? save.trim() : '';
		field = field != null ? field.trim() : '';
		return save.length == 0 && field.length == 0 ? null : {save: save, field: field};
	}

	public static function isUnlockConditionEmpty(condition:UnlockData):Bool
		return condition == null || createUnlockCondition(condition.save, condition.field) == null;

	static function removeEmptyUnlockConditions(target:Dynamic, fields:Array<String>):Void
	{
		for(field in fields)
			if(isUnlockConditionEmpty(Reflect.field(target, field))) Reflect.deleteField(target, field);
	}

	// Read either file format without inserting inherited runtime values into editor data.
	public static function getSongData(song:Dynamic):SongData
	{
		if(!Std.isOfType(song, Array)) return Reflect.copy(song);
		var values:Array<Dynamic> = cast song;
		var result:SongData = {songName: values[0], icon: values[1], backgroundColor: values[2]};
		if(values.length == 4 && values[3] != null)
			result.unlockedAfter = {save: values[3][0], field: values[3][1]};
		return result;
	}

	// HELP: Is there any way to convert a WeekFile to WeekData without having to put all variables there manually? I'm kind of a noob in haxe lmao
	public function new(weekFile:WeekFile, fileName:String) {
		// here ya go - MiguelItsOut
		for (field in Reflect.fields(weekFile)) {
			if (field == 'songs')
				continue;
			if(Reflect.fields(this).contains(field)) // Reflect.hasField() won't fucking work :/
				Reflect.setProperty(this, field, Reflect.getProperty(weekFile, field));
		}

		this.fileName = fileName;
		this.songs = [];

		for (s in weekFile.songs) {
			var sd:SongData = getSongData(s);
			if (sd.difficulties == null)
			{
				sd.difficulties = this.difficulties != null && this.difficulties.trim().length > 0 ? this.difficulties : Difficulty.vanillaList.join(',');
				if (sd.displayedDifficulties == null)
					sd.displayedDifficulties = this.displayedDifficulties;
			}
			// An explicit song difficulty list starts a new display-name scope.
			this.songs.push(sd);
		}

	}

	public static function reloadWeekFiles(isStoryMode:Null<Bool> = false)
	{
		weeksList = [];
		weeksLoaded.clear();
		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods(), Paths.getSharedPath()];
		var originalLength:Int = directories.length;

		for (mod in Mods.parseList().enabled)
			directories.push(Paths.mods(mod + '/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath()];
		var originalLength:Int = directories.length;
		#end

		var sexList:Array<String> = CoolUtil.coolTextFile(Paths.getSharedPath('weeks/weekList.txt'));
		for (i in 0...sexList.length) {
			for (j in 0...directories.length) {
				var fileToCheck:String = directories[j] + 'weeks/' + sexList[i] + '.json';
				if(!weeksLoaded.exists(sexList[i])) {
					var week:WeekFile = getWeekFile(fileToCheck);
					if(week != null) {
						var weekFile:WeekData = new WeekData(week, sexList[i]);

						#if MODS_ALLOWED
						if(j >= originalLength) {
							weekFile.folder = directories[j].substring(Paths.mods().length, directories[j].length-1);
						}
						#end

						if(weekFile != null && (isStoryMode == null || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))) {
							weeksLoaded.set(sexList[i], weekFile);
							weeksList.push(sexList[i]);
						}
					}
				}
			}
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i] + 'weeks/';
			if(FileSystem.exists(directory)) {
				var listOfWeeks:Array<String> = CoolUtil.coolTextFile(directory + 'weekList.txt');
				for (daWeek in listOfWeeks)
				{
					var path:String = directory + daWeek + '.json';
					if(FileSystem.exists(path))
					{
						addWeek(daWeek, path, directories[i], i, originalLength);
					}
				}

				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						addWeek(file.substr(0, file.length - 5), path, directories[i], i, originalLength);
					}
				}
			}
		}
		#end
	}

	private static function addWeek(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int)
	{
		if(!weeksLoaded.exists(weekToCheck))
		{
			var week:WeekFile = getWeekFile(path);
			if(week != null)
			{
				var weekFile:WeekData = new WeekData(week, weekToCheck);
				if(i >= originalLength)
				{
					#if MODS_ALLOWED
					weekFile.folder = directory.substring(Paths.mods().length, directory.length-1);
					#end
				}
				if((PlayState.isStoryMode && !weekFile.hideStoryMode) || (!PlayState.isStoryMode && !weekFile.hideFreeplay))
				{
					weeksLoaded.set(weekToCheck, weekFile);
					weeksList.push(weekToCheck);
				}
			}
		}
	}

	private static function getWeekFile(path:String):WeekFile {
		var rawJson:String = null;
		#if MODS_ALLOWED
		if(FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if(OpenFlAssets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end

		if(rawJson != null && rawJson.length > 0) {
			return cast tjson.TJSON.parse(rawJson);
		}
		return null;
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE

	//To use on PlayState.hx or Highscore stuff
	public static function getWeekFileName():String {
		return weeksList[PlayState.storyWeek];
	}

	//Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():WeekData {
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);
	}

	public static function getStorySongs(week:WeekData):Array<SongData>
	{
		if(week == null || week.songs == null) return [];
		return week.songs;
	}

	public static function getFreeplayRedirectSong(week:WeekData):Dynamic
	{
		if(week != null && week.redirectToFreeplay && week.songs != null && week.songs.length > 0)
			return week.songs[0];
		return null;
	}

	public static function setDirectoryFromWeek(?data:WeekData = null) {
		Mods.currentModDirectory = '';
		if(data != null && data.folder != null && data.folder.length > 0) {
			Mods.currentModDirectory = data.folder;
		}
	}
}

