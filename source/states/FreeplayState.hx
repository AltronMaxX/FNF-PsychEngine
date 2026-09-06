package states;

import flixel.util.FlxSave;
import flixel.FlxObject;
import backend.InputFormatter;
import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import states.TitleState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;

import haxe.Json;

using Lambda;

class FreeplayState extends MusicBeatState
{
	var _songs:Map<String, Array<SongMetadata>> = [];

	var unavailableDiffs:Array<Int> = [];
	var charDiff:Map<String, Array<String>> = [];

	var freeplayCharacters:Array<String> = [];
	var songs(get, never):Array<SongMetadata>;

	private function get_songs():Array<SongMetadata> {
		final curDiff = Difficulty.list[curDifficulty].toLowerCase();
		return _songs[curDiff];
	}

	var selector:FlxText;
	private static var curSelectedChar:Int = 0;
	private static var curSelected:Int = 0;
	private static var requestedSongName:String = null;
	private static var requestedSongFolder:String = null;
	private static var requestedSongDiff:String = null;
	private static var requestedFreeplayChar:String = null;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var diffSel:BubbleSelector;
	var leftSel:FlxText;
	var rightSel:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	var bpmInput:flixel.addons.ui.FlxInputText;
	var bpmText:FlxText;

	var charBubbles:BubbleSelector;
	var selectedCharIcon:HealthIcon;
	var bpmTitle:Float;
	var bpmSong:Float;

	override function create()
	{
		super.create();
		//Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;
			final weekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

			var hasAvailableSong = false;
			for (song in weekData.songs) {
				final sd:SongData = cast song;
				if (sd.unlockedAfter != null && sd.showAfter != null) {

					loadSave(sd.unlockedAfter.save);
					loadSave(sd.showAfter.save);

					hasAvailableSong = shouldShowLockedSong(sd.showAfter);
				} else 
					hasAvailableSong = true;

				var preparedDiffs = sd.difficulties.split(',').map(function(str:String):String {return str.trim().toLowerCase();});
				if (!charDiff.exists(weekData.freeplayCharacter)) 
					charDiff.set(weekData.freeplayCharacter, []);

				for (diff in preparedDiffs) {
					if (!charDiff[weekData.freeplayCharacter].contains(diff) && hasAvailableSong)
						charDiff[weekData.freeplayCharacter].push(diff);
				}
			}

			if (!freeplayCharacters.contains(weekData.freeplayCharacter) && hasAvailableSong) {
				freeplayCharacters.push(weekData.freeplayCharacter);
			}
		}
		
		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;
			final weekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

			if (weekData.freeplayCharacter == freeplayCharacters[curSelectedChar])
				reloadSongs(i);
		}

		Difficulty.loadFromAllWeeks();

		for (diff in Difficulty.list) {
			if (!_songs.exists(diff.toLowerCase()) || _songs[diff.toLowerCase()].length == 0) {
				unavailableDiffs.push(Difficulty.list.indexOf(diff));
			}
		}

		Mods.loadTopMod();

		curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(lastDifficultyName)));

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		createSongTexts();
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 110, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		leftSel = new FlxText(diffText.x + 67, diffText.y + 26);
		leftSel.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		leftSel.text = '<';
		add(leftSel);

		var availableDiffs = 0;
		for (diff in Difficulty.list) {
			for (key in charDiff.keys()) {
				if (freeplayCharacters.contains(key) && charDiff[key].contains(diff.toLowerCase())) {
					availableDiffs++;
					break;
				}
			}
		}

		diffSel = new BubbleSelector(availableDiffs);
		diffSel.x = leftSel.x + 10;
		diffSel.y = leftSel.y + 7;
		add(diffSel);
		diffSel.loadUnavailable(unavailableDiffs);

		rightSel = new FlxText(diffText.x + 67 + leftSel.width + diffSel.width + 25, diffText.y + 26);
		rightSel.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		rightSel.text = '>';
		add(rightSel);

		add(scoreText);

		bpmTitle = TitleState.musicBPM;

		bpmText = new FlxText(diffText.x, diffSel.y + 28, 0, "Cur bpm:", 12);
		bpmText.font = scoreText.font;
		bpmText.visible = false;
		add(bpmText);

		bpmInput = new flixel.addons.ui.FlxInputText(bpmText.x, bpmText.y + 18, 140, "", 12);
		bpmInput.font = bpmInput.font;
		bpmInput.text = Std.string(bpmTitle);
		bpmInput.visible = false;
		Conductor.bpm = bpmTitle;
		add(bpmInput);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		var charSelectBG = new FlxSprite(FlxG.width - 326, FlxG.height - 176).makeGraphic(326, 150, 0xFF000000);
		charSelectBG.alpha = 0.6;

		var charArrow1 = new FlxSprite();
		charArrow1.loadGraphic(Paths.image('charArrow'));
		charArrow1.x = FlxG.width - 316;
		charArrow1.y = FlxG.height - 146;

		var prevText = new FlxText();
		prevText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		prevText.text = InputFormatter.getKeyName(ClientPrefs.keyBinds.get('ui_prev')[0]);
		prevText.x = charArrow1.x + prevText.width;
		prevText.y = FlxG.height - 26 - prevText.height;

		selectedCharIcon = new HealthIcon(freeplayCharacters[curSelectedChar]);
		selectedCharIcon.x = FlxG.width - 90 - selectedCharIcon.width;
		selectedCharIcon.y = FlxG.height - 26 - selectedCharIcon.height;
		selectedCharIcon.flipX = true;

		charBubbles = new BubbleSelector(freeplayCharacters.length);
		charBubbles.x = selectedCharIcon.x + 40;
		charBubbles.y = selectedCharIcon.y + 125;
		charBubbles.changeSelection(0);

		var charArrow2 = new FlxSprite();
		charArrow2.loadGraphic(Paths.image('charArrow'));
		charArrow2.x = FlxG.width - 60;
		charArrow2.y = FlxG.height - 146;
		charArrow2.flipX = true;

		var nextText = new FlxText();
		nextText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		nextText.text = InputFormatter.getKeyName(ClientPrefs.keyBinds.get('ui_next')[0]);
		nextText.x = charArrow2.x;
		nextText.y = FlxG.height - 26 - nextText.height;

		if (freeplayCharacters.length > 1) {
			add(charSelectBG);
			add(charArrow1);
			add(prevText);
			add(selectedCharIcon);
			add(charArrow2);
			add(nextText);
			add(charBubbles);
		}
		
		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		var leText:String = Language.getPhrase("freeplay_tip", "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);

		if(requestedSongName != null)
		{
			curSelectedChar = freeplayCharacters.indexOf('bf');
			if (freeplayCharacters.contains(requestedFreeplayChar))
				curSelectedChar = freeplayCharacters.indexOf(requestedFreeplayChar);
			changeCharacter();
			var songArr = _songs[requestedSongDiff];
			for (i in 0...songArr.length)
			{
				if(songArr[i].songName == requestedSongName && (requestedSongFolder == null 
					|| requestedSongFolder.length < 1 || songArr[i].folder == requestedSongFolder))
				{
					curSelected = i;
					curDifficulty = Difficulty.getDiffID(requestedSongDiff);
					break;
				}
			}
			requestedSongName = null;
			requestedSongFolder = null;
			requestedSongDiff = null;
		}
		
		changeSelection();
		updateTexts();
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int, 
		unlockedAfter:Null<UnlockData>, showAfter:Null<UnlockData>, linkedTo:Array<String>, diffs:Array<String>)
	{
		final metadata = new SongMetadata(songName, weekNum, songCharacter, color, unlockedAfter, showAfter, linkedTo);
		for (diff in diffs) {
			_songs[diff].push(metadata);
		}
	}

	public static function queueSongSelection(songName:String, diff:String, char:String, ?folder:String = '')
	{
		requestedSongName = songName;
		requestedSongFolder = folder;
		requestedSongDiff = diff;
		requestedFreeplayChar = char;
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	function resetMenuBeatTiming()
	{
		bpmSong = 0;
		Conductor.bpmChangeMap = [];
		Conductor.bpm = bpmTitle;
	}

	function applySongBeatTiming(songData:SwagSong)
	{
		if(songData == null) return;

		Conductor.mapBPMChanges(songData);
		bpmSong = songData.bpm;
		songs[curSelected].bpm = bpmSong;
		Conductor.bpm = bpmSong;
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var bpmSettingEnabled:Bool = false;
	var bpmSettingActive:Bool = false;
	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		if(WeekData.weeksList.length < 1)
			return;

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) //No decimals, add an empty space
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2) //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
			positionHighscore();
			
			if(songs.length > 1)
			{
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;	
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_PREV_P) {
				changeCharacter(-1);
			} else if (controls.UI_NEXT_P) {
				changeCharacter(1);
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK && !bpmSettingActive)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				resetMenuBeatTiming();
				PlayState.SONG = null;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else 
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		if (controls.justPressed('debug_1') && !bpmSettingActive && bpmSettingEnabled)
		{
			bpmSettingActive = true;
			FlxG.mouse.visible = true;
			scoreBG.makeGraphic(1, 152, 0xFF000000);
			bpmInput.visible = true;
			bpmText.visible = true;
		}
		else if (controls.justPressed('debug_1') && bpmSettingActive && bpmSettingEnabled)
		{
			bpmSettingActive = false;
			FlxG.mouse.visible = false;
			scoreBG.makeGraphic(1, 110, 0xFF000000);
			bpmInput.visible = false;
			bpmText.visible = false;
			bpmTitle = Std.parseFloat(bpmInput.text);
			if(!player.playingMusic)
				Conductor.bpm = bpmTitle;
		}

		if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE)
		{
			if(instPlaying != curSelected && !player.playingMusic && !isSongLocked(curSelected))
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				applySongBeatTiming(PlayState.SONG);

				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
						if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch(e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}
					
					opponentVocals = new FlxSound();
					try
					{
						//trace('please work...');
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
							//trace('yaaay!!');
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						//trace('FUUUCK');
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic && !bpmSettingActive && !isSongLocked(curSelected))
		{
			persistentUpdate = false;
			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

			try
			{
				Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			}
			catch(e:haxe.Exception)
			{
				trace('ERROR! ${e.message}');

				var errorStr:String = e.message;
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
				else errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			stopMusicPlay = true;

			destroyFreeplayVocals();
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if(controls.RESET && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateTexts(elapsed);
		super.update(elapsed);

		var mult:Float = FlxMath.lerp(1, iconArray[curSelected].scale.x, Math.exp(-elapsed * 9 * ClientPrefs.getGameplaySetting('songspeed')));
		iconArray[curSelected].scale.set(mult, mult);
		iconArray[curSelected].updateHitbox();

		if (curBeat % 4 == 0)
		{
			var multX:Float = FlxMath.lerp(1, bg.scale.x, Math.exp(-elapsed * 9 * ClientPrefs.getGameplaySetting('songspeed')));
			var multY:Float = FlxMath.lerp(1, bg.scale.y, Math.exp(-elapsed * 9 * ClientPrefs.getGameplaySetting('songspeed')));
			bg.scale.set(multX, multY);
			bg.screenCenter();
			bg.updateHitbox();
		}
	}
	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		var futureDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);

		while (unavailableDiffs.contains(futureDifficulty)) {
			change = change < 0 ? change - 1 : change + 1;
			futureDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		}

		var diffName = Difficulty.getString(futureDifficulty, false).toLowerCase();

		//show only this diff songs
		final sList = _songs[diffName];
		if (!areInstancesEqual(sList, songs) && !unavailableDiffs.contains(futureDifficulty)) {
			var lastSong = songs[curSelected];
			curDifficulty = futureDifficulty;
			createSongTexts();
			if (change != 0) // if diff change by user input
			{
				curSelected = 0;
				for (song in songs) {
					if (lastSong != null) {
						for (link in song.linkedTo) {
							if (link == lastSong.songName) {
								curSelected = songs.indexOf(song);
								break;
							}
						}
						if (curSelected == 0) {
							for (link in lastSong.linkedTo) {
								if (link == song.songName) {
									curSelected = songs.indexOf(song);
									break;
								}
							}
						}
						if (curSelected == 0 && song.songName == lastSong.songName) 
							curSelected = songs.indexOf(song);
					}
				}
			}
			changeSelection(0, true, false);
		}

		curDifficulty = futureDifficulty;

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		diffText.text = displayDiff.toUpperCase();

		diffSel.changeSelection(curDifficulty);

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	private function areInstancesEqual(arr1:Array<SongMetadata>, arr2:Array<SongMetadata>):Bool {
		if (arr1.length != arr2.length) return false;
		for (i in 0...arr1.length) {
			if (arr1[i] != arr2[i]) return false;
		}
		return true;
	}

	function changeCharacter(change:Int = 0, playSound:Bool = true) {
		var lastSong = songs[curSelected];
		if (player.playingMusic)
			return;

		if (freeplayCharacters.length == 1)
			return;

		_songs = [];

		unavailableDiffs = [];
		curSelectedChar = FlxMath.wrap(curSelectedChar + change, 0, freeplayCharacters.length-1);
		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;
			final weekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

			if (weekData.freeplayCharacter == freeplayCharacters[curSelectedChar]) 
				reloadSongs(i);
		}

		Difficulty.loadFromAllWeeks();

		for (diff in Difficulty.list) {
			if (!_songs.exists(diff.toLowerCase()) || _songs[diff.toLowerCase()].length == 0) {
				unavailableDiffs.push(Difficulty.list.indexOf(diff));
			}
		}

		if (!_songs.exists(Difficulty.list[curDifficulty].toLowerCase()) || _songs[Difficulty.list[curDifficulty].toLowerCase()].length == 0) {
			for (diff in Difficulty.list) { //find first available if not exists
				if (_songs.exists(diff.toLowerCase()) && _songs[diff.toLowerCase()].length > 0) {
					curDifficulty = Difficulty.list.indexOf(diff);
					break;
				}				
			}
		}	

		selectedCharIcon.changeIcon(freeplayCharacters[curSelectedChar]);
		selectedCharIcon.x = FlxG.width - 90 - selectedCharIcon.width;
		selectedCharIcon.y = FlxG.height - 26 - selectedCharIcon.height;
		selectedCharIcon.flipX = true;
		createSongTexts();

		charBubbles.changeSelection(curSelectedChar);

		curSelected = 0;
		for (song in songs) {
			if (lastSong != null) {
				for (link in song.linkedTo) {
					if (link == lastSong.songName) {
						curSelected = songs.indexOf(song);
						break;
					}
				}
				if (curSelected == 0) {
					for (link in lastSong.linkedTo) {
						if (link == song.songName) {
							curSelected = songs.indexOf(song);
							break;
						}
					}
				}
				if (curSelected == 0 && song.songName == lastSong.songName) 
					curSelected = songs.indexOf(song);
			}
		}
		changeSelection();

		diffSel.loadUnavailable(unavailableDiffs);
		diffSel.changeSelection(curDifficulty);
	}

	function changeSelection(change:Int = 0, playSound:Bool = true, updateDiff:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];
			item.alpha = 0.6;
			icon.alpha = 0.6;
			icon.scale.set(1, 1);
			icon.updateHitbox();
			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		//Difficulty.loadFromWeek();

		// Idk what this code is doing
		/*var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.defaultList.indexOf(lastDifficultyName);
		if(savedDiff != null && !Difficulty.defaultList.contains(savedDiff) && Difficulty.defaultList.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.defaultList.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;*/

		if (updateDiff)
			changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
		leftSel.x = Std.int(scoreBG.x + (scoreBG.width / 2)) - diffSel.width / 2 - 25;
		diffSel.x = Std.int(scoreBG.x + (scoreBG.width / 2)) - diffSel.width / 2;
		rightSel.x = leftSel.x + diffSel.width + 27;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			var icon:HealthIcon = iconArray[i];
			icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		if(!stopMusicPlay)
			resetMenuBeatTiming();

		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}	

	override function beatHit()
	{
		super.beatHit();

		iconArray[curSelected].scale.set(1.2, 1.2);
		iconArray[curSelected].updateHitbox();

		if (curBeat % 4 == 0)
		{
			bg.scale.set(1.05, 1.05);
			bg.screenCenter();
			bg.updateHitbox();
		}
	}

	private function reloadSongs(index:Int) {
		var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[index]);

		WeekData.setDirectoryFromWeek(leWeek);
		for (song in leWeek.songs)
		{
			final sd:SongData = cast song;
			var colors:Array<Int> = sd.backgroundColor;
			if(colors == null || colors.length < 3)
			{
				colors = [146, 113, 253];
			}
			if (sd.unlockedAfter != null) {
				if (!shouldShowLockedSong(sd.showAfter) && checkLock(sd.unlockedAfter.save, sd.unlockedAfter.field))
					continue;
			}
			var preparedDiffs = sd.difficulties.split(',').map(function(str:String):String {return str.trim().toLowerCase();});
			for (diff in preparedDiffs) {
				if (!_songs.exists(diff)) {
					_songs.set(diff, []);
				}
			}

			var link = [];
			link = sd.linkedTo.split(',');
			for (i in 0...link.length) {
				link[i] = link[i].trim();
			}

			addSong(sd.songName, index, sd.icon, FlxColor.fromRGB(colors[0], colors[1], colors[2]), sd.unlockedAfter, sd.showAfter, link, preparedDiffs);	
		}
	}

	private function createSongTexts() {
		_lastVisibles = [];
		grpSongs.clear();
		for (icon in iconArray) {
			remove(icon);
		}
		iconArray = [];
		for (i in 0...songs.length)
		{
			var songData = songs[i];
			var displayText = isSongLocked(i) && shouldShowLockedSong(songData.showAfter) ? lockedSongName(songData.songName) : songData.songName;
			var songText:Alphabet = new Alphabet(90, 320, displayText, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songData.folder;
			var icon:HealthIcon = new HealthIcon(songData.songCharacter);
			icon.sprTracker = songText;
			if (isSongLocked(i) && shouldShowLockedSong(songData.showAfter))
				icon.color = FlxColor.BLACK;

			
			// too laggy with a lot of songs, so i had to recode the logic for it
			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);
		}
	}

	private function lockedSongName(name:String): String {
		var ret = "";
		for (i in 0...name.length) {
			if (name.charAt(i) == " ")
				ret += " ";
			else
				ret += "?";
		}
		return ret;
	}

	private function shouldShowLockedSong(showAfter:UnlockData):Bool
	{
		if (showAfter != null)
			if (showAfter.field != null && showAfter.save != null)
				return !checkLock(showAfter.save, showAfter.field);
		return false;
	}

	private function isSongLocked(index:Int):Bool
	{
		final songData = songs[index];
		if (!songData.isUnlockedAfterNull())
			return checkLock(songData.unlockedAfter.save, songData.unlockedAfter.field);
		return false;
	}
	
	private function checkLock(name:String, field:String):Bool {
		final variables = MusicBeatState.getVariables(); // just copy from lua function
		if (variables.exists('save_$name'))
		{
			final saveData = variables.get('save_$name').data;
			if (Reflect.hasField(saveData, field)) 
				return !Reflect.field(saveData, field);	
			else 
				return true;
		} else {
			return true;
		}
	}

	private function loadSave(name:String, ?dir:String = 'psychenginemods') {
		var variables = MusicBeatState.getVariables();
		if(!variables.exists('save_$name'))
		{
			var save:FlxSave = new FlxSave();
			save.bind(name, CoolUtil.getSavePath() + '/' + dir);
			variables.set('save_$name', save);
		}
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;
	public var unlockedAfter:UnlockData = null;
	public var showAfter:UnlockData = null;
	public var linkedTo:Array<String> = [];
	public var bpm:Float = 0;

	public function new(song:String, week:Int, songCharacter:String, color:Int, unlockedAfter:Null<UnlockData>, showAfter:Null<UnlockData>, ?linkedTo:Array<String>)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
		if (unlockedAfter != null) {
			this.unlockedAfter = unlockedAfter;
		}
		if (showAfter != null) {
			this.showAfter = showAfter;
		}
		this.linkedTo = linkedTo ?? [];
	}


	public function isUnlockedAfterNull(): Bool {
		return unlockedAfter == null || (unlockedAfter.field == null && unlockedAfter.save == null);
	}

	public function isShowAfterNull(): Bool {
		return showAfter == null || (showAfter.field == null && showAfter.save == null);
	}

	public function toString():String {
		return '$songName:$songCharacter:$unlockedAfter';
	}
}

typedef UnlockedAfter = {
	save:String,
	field:String,
	show:Bool
}

class BubbleSelector extends FlxTypedGroup<FlxObject> {
	public var bubbleCount = 0;

	var bubbles:Array<FlxSprite> = [];
	var unavailableBubbles:Array<Int> = [];

	public function new (count:Int) {
		super();

		regenerateBubbles(count);
	}

	public function regenerateBubbles(count:Int) {
		bubbleCount = count;

		for (i in 0...count) {
			var sprite = new FlxSprite();
			sprite.loadGraphic(Paths.image('diff'));
			sprite.x = sprite.width * i;
			sprite.y = 0;
			add(sprite);
			bubbles.push(sprite);
		}
	}

	public function changeSelection(index:Int) {
		for (i in 0...bubbles.length) {
			if (unavailableBubbles.contains(i))
				bubbles[i].loadGraphic(Paths.image('diffUnavailable'));
			else
				bubbles[i].loadGraphic(Paths.image('diff'));
		}
		bubbles[index].loadGraphic(Paths.image('diffSelected'));
	}

	public function loadUnavailable(unavailable:Array<Int>) { //array of unavailable indexes
		for (i in 0...bubbles.length) {
			bubbles[i].loadGraphic(Paths.image('diff'));
		}
		for (i in unavailable) {
			if (i > bubbles.length - 1) continue;
			bubbles[i].loadGraphic(Paths.image('diffUnavailable'));
		}
		unavailableBubbles = unavailable;
	}

	public var x(never, set):Float;
	public var y(default, set):Float;

	public var width(get, never):Float;

	function set_x(value:Float):Float {
		for (i in 0...bubbles.length) {
			bubbles[i].x = value + ((bubbles[i].width + 5) * i);
		}

		return value;
	}

	function set_y(value:Float):Float {
		for (i in 0...bubbles.length) {
			bubbles[i].y = value;
		}
		y = value;
		
		return value;
	}

	function get_width():Float {
		return bubbles[bubbleCount - 1].x - bubbles[0].x + bubbles[0].width;
	}
}