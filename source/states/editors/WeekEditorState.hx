package states.editors;

import backend.WeekData;

import openfl.utils.Assets;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;
import lime.system.Clipboard;
import haxe.Json;

import objects.HealthIcon;
import objects.MenuCharacter;
import objects.MenuItem;

import states.editors.MasterEditorMenu;
import states.editors.content.Prompt;

class WeekEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	var txtWeekTitle:FlxText;
	var bgSprite:FlxSprite;
	var lock:FlxSprite;
	var txtTracklist:FlxText;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var weekThing:MenuItem;
	var missingFileText:FlxText;

	public static var unsavedProgress:Bool = false;

	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
		else weekFileName = 'week1';
	}

	override function create() {
		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;
		
		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);
		bgSprite.antialiasing = ClientPrefs.data.antialiasing;

		weekThing = new MenuItem(0, bgSprite.y + 396, weekFileName);
		weekThing.y += weekThing.height + 20;
		weekThing.antialiasing = ClientPrefs.data.antialiasing;
		add(weekThing);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);
		
		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();
		
		lock = new FlxSprite();
		lock.frames = ui_tex;
		lock.animation.addByPrefix('lock', 'lock');
		lock.animation.play('lock');
		lock.antialiasing = ClientPrefs.data.antialiasing;
		add(lock);
		
		missingFileText = new FlxText(0, 0, FlxG.width, "");
		missingFileText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingFileText.borderSize = 2;
		missingFileText.visible = false;
		add(missingFileText); 
		
		var charArray:Array<String> = weekFile.weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07, bgSprite.y + 435).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(tracksSprite);

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, "", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = Paths.font("vcr.ttf");
		txtTracklist.color = 0xFFe55777;
		add(txtTracklist);
		add(txtWeekTitle);

		addEditorBox();
		reloadAllShit();

		FlxG.mouse.visible = true;

		super.create();
	}

	var UI_box:PsychUIBox;
	function addEditorBox() {
		UI_box = new PsychUIBox(FlxG.width, FlxG.height, 250, 375, ['Other', 'Week']);
		UI_box.x -= UI_box.width;
		UI_box.y -= UI_box.height;
		UI_box.scrollFactor.set();
		add(UI_box);
		addOtherUI();
		addWeekUI();
		
		UI_box.selectedName = 'Week';
		add(UI_box);

		var loadWeekButton:PsychUIButton = new PsychUIButton(0, 650, "Load Week", function() loadWeek());
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);
		
		var freeplayButton:PsychUIButton = new PsychUIButton(0, 650, "Freeplay", function() MusicBeatState.switchState(new WeekEditorFreeplayState(weekFile)));
		freeplayButton.screenCenter(X);
		add(freeplayButton);
	
		var saveWeekButton:PsychUIButton = new PsychUIButton(0, 650, "Save Week", function() saveWeek(weekFile));
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}

	var songsInputText:PsychUIInputText;
	var backgroundInputText:PsychUIInputText;
	var displayNameInputText:PsychUIInputText;
	var weekNameInputText:PsychUIInputText;
	var weekFileInputText:PsychUIInputText;
	
	var opponentInputText:PsychUIInputText;
	var boyfriendInputText:PsychUIInputText;
	var girlfriendInputText:PsychUIInputText;

	var hideCheckbox:PsychUICheckBox;

	public static var weekFileName:String = 'week1';
	
	function addWeekUI() {
		var tab_group = UI_box.getTab('Week').menu;

		songsInputText = new PsychUIInputText(10, 30, 200, '', 8);

		opponentInputText = new PsychUIInputText(10, songsInputText.y + 40, 70, '', 8);
		boyfriendInputText = new PsychUIInputText(opponentInputText.x + 75, opponentInputText.y, 70, '', 8);
		girlfriendInputText = new PsychUIInputText(boyfriendInputText.x + 75, opponentInputText.y, 70, '', 8);

		backgroundInputText = new PsychUIInputText(10, opponentInputText.y + 40, 120, '', 8);
		displayNameInputText = new PsychUIInputText(10, backgroundInputText.y + 60, 200, '', 8);
		weekNameInputText = new PsychUIInputText(10, displayNameInputText.y + 60, 150, '', 8);
		weekFileInputText = new PsychUIInputText(10, weekNameInputText.y + 40, 100, '', 8);
		reloadWeekThing();

		hideCheckbox = new PsychUICheckBox(10, weekFileInputText.y + 40, "Hide Week from Story Mode?", 100);
		hideCheckbox.onClick = function()
		{
			weekFile.hideStoryMode = hideCheckbox.checked;
			unsavedProgress = true;
		};

		tab_group.add(new FlxText(songsInputText.x, songsInputText.y - 18, 0, 'Songs:'));
		tab_group.add(new FlxText(opponentInputText.x, opponentInputText.y - 18, 0, 'Characters:'));
		tab_group.add(new FlxText(backgroundInputText.x, backgroundInputText.y - 18, 0, 'Background Asset:'));
		tab_group.add(new FlxText(displayNameInputText.x, displayNameInputText.y - 18, 0, 'Display Name:'));
		tab_group.add(new FlxText(weekNameInputText.x, weekNameInputText.y - 18, 0, 'Week Name (for Reset Score Menu):'));
		tab_group.add(new FlxText(weekFileInputText.x, weekFileInputText.y - 18, 0, 'Week File:'));

		tab_group.add(songsInputText);
		tab_group.add(opponentInputText);
		tab_group.add(boyfriendInputText);
		tab_group.add(girlfriendInputText);
		tab_group.add(backgroundInputText);

		tab_group.add(displayNameInputText);
		tab_group.add(weekNameInputText);
		tab_group.add(weekFileInputText);
		tab_group.add(hideCheckbox);
	}

	var weekBeforeInputText:PsychUIInputText;
	var difficultiesInputText:PsychUIInputText;
	var lockedCheckbox:PsychUICheckBox;
	var hiddenUntilUnlockCheckbox:PsychUICheckBox;

	function addOtherUI() {
		var tab_group = UI_box.getTab('Other').menu;

		lockedCheckbox = new PsychUICheckBox(10, 30, "Week starts Locked", 100);
		lockedCheckbox.onClick = function()
		{
			weekFile.startUnlocked = !lockedCheckbox.checked;
			lock.visible = lockedCheckbox.checked;
			hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);
			unsavedProgress = true;
		};

		hiddenUntilUnlockCheckbox = new PsychUICheckBox(10, lockedCheckbox.y + 25, "Hidden until Unlocked", 110);
		hiddenUntilUnlockCheckbox.onClick = function()
		{
			weekFile.hiddenUntilUnlocked = hiddenUntilUnlockCheckbox.checked;
			unsavedProgress = true;
		};
		hiddenUntilUnlockCheckbox.alpha = 0.4;


		weekBeforeInputText = new PsychUIInputText(10, hiddenUntilUnlockCheckbox.y + 55, 100, '', 8);
		difficultiesInputText = new PsychUIInputText(10, weekBeforeInputText.y + 60, 200, '', 8);

		var redirectToFreeplayCheckbox:PsychUICheckBox = new PsychUICheckBox(10, difficultiesInputText.y + 50, "Redirect to Freeplay", 100);
		redirectToFreeplayCheckbox.checked = weekFile.redirectToFreeplay == true;
		redirectToFreeplayCheckbox.onClick = function()
		{
			weekFile.redirectToFreeplay = redirectToFreeplayCheckbox.checked;
			WeekEditorState.unsavedProgress = true;
		};

		tab_group.add(redirectToFreeplayCheckbox);
		
		tab_group.add(new FlxText(weekBeforeInputText.x, weekBeforeInputText.y - 28, 0, 'Week File name of the Week you have\nto finish for Unlocking:'));
		tab_group.add(new FlxText(difficultiesInputText.x, difficultiesInputText.y - 20, 0, 'Difficulties:'));
		tab_group.add(new FlxText(difficultiesInputText.x, difficultiesInputText.y + 20, 0, 'Default difficulties are "Easy, Normal, Hard"\nwithout quotes.'));
		tab_group.add(weekBeforeInputText);
		tab_group.add(difficultiesInputText);
		tab_group.add(hiddenUntilUnlockCheckbox);
		tab_group.add(lockedCheckbox);
		tab_group.add(redirectToFreeplayCheckbox);
	}

	//Used on onCreate and when you load a week
	function reloadAllShit() {
		var weekString:String = "";
		if (!Reflect.hasField(weekFile.songs[0], "songName") && !Reflect.hasField(weekFile.songs[0], "icon") 
			&& !Reflect.hasField(weekFile.songs[0], "backgroundColor"))
			weekString = weekFile.songs[0][0];
			for (i in 1...weekFile.songs.length) {
			if (!Reflect.hasField(weekFile.songs[i], "songName") && !Reflect.hasField(weekFile.songs[i], "icon") 
				&& !Reflect.hasField(weekFile.songs[i], "backgroundColor"))
				weekString += ', ' + weekFile.songs[i][0];
			else 
				weekString += ', ' + weekFile.songs[i].songName;
		}
		songsInputText.text = weekString;
		backgroundInputText.text = weekFile.weekBackground;
		displayNameInputText.text = weekFile.storyName;
		weekNameInputText.text = weekFile.weekName;
		weekFileInputText.text = weekFileName;
		
		opponentInputText.text = weekFile.weekCharacters[0];
		boyfriendInputText.text = weekFile.weekCharacters[1];
		girlfriendInputText.text = weekFile.weekCharacters[2];

		hideCheckbox.checked = weekFile.hideStoryMode;

		weekBeforeInputText.text = weekFile.weekBefore;

		difficultiesInputText.text = '';
		if(weekFile.difficulties != null) difficultiesInputText.text = weekFile.difficulties;

		lockedCheckbox.checked = !weekFile.startUnlocked;
		lock.visible = lockedCheckbox.checked;
		
		hiddenUntilUnlockCheckbox.checked = weekFile.hiddenUntilUnlocked;
		hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);

		reloadBG();
		reloadWeekThing();
		updateText();
	}

	function updateText()
	{
		for (i in 0...grpWeekCharacters.length) {
			grpWeekCharacters.members[i].changeCharacter(weekFile.weekCharacters[i]);
		}

		var stringThing:Array<String> = [];
		var songStart:Int = weekFile.redirectToFreeplay == true ? 1 : 0;
		for (i in songStart...weekFile.songs.length) {
			if (!Reflect.hasField(weekFile.songs[i], "songName") && !Reflect.hasField(weekFile.songs[i], "icon") 
				&& !Reflect.hasField(weekFile.songs[i], "backgroundColor"))
				stringThing.push(weekFile.songs[i][0]);
			else
				stringThing.push(weekFile.songs[i].songName);
		}
		if(stringThing.length < 1 && weekFile.redirectToFreeplay == true && weekFile.songs.length > 0) {
			if (!Reflect.hasField(weekFile.songs[0], "songName") && !Reflect.hasField(weekFile.songs[0], "icon") 
				&& !Reflect.hasField(weekFile.songs[0], "backgroundColor"))
				stringThing.push(weekFile.songs[0][0] + ' (Freeplay)');
			else
				stringThing.push(weekFile.songs[0].songName + ' (Freeplay)');
		}
			

		txtTracklist.text = '';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;
		
		txtWeekTitle.text = weekFile.storyName.toUpperCase();
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);
	}

	function reloadBG() {
		bgSprite.visible = true;
		var assetName:String = weekFile.weekBackground;

		var isMissing:Bool = true;
		if(assetName != null && assetName.length > 0) {
			if( #if MODS_ALLOWED FileSystem.exists(Paths.modsImages('menubackgrounds/menu_' + assetName)) || #end
			Assets.exists(Paths.getPath('images/menubackgrounds/menu_' + assetName + '.png', IMAGE), IMAGE)) {
				bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
				isMissing = false;
			}
		}

		if(isMissing) {
			bgSprite.visible = false;
		}
	}

	function reloadWeekThing() {
		weekThing.visible = true;
		missingFileText.visible = false;
		var assetName:String = weekFileInputText.text.trim();
		
		var isMissing:Bool = true;
		if(assetName != null && assetName.length > 0) {
			if( #if MODS_ALLOWED FileSystem.exists(Paths.modsImages('storymenu/' + assetName)) || #end
			Assets.exists(Paths.getPath('images/storymenu/' + assetName + '.png', IMAGE), IMAGE)) {
				weekThing.loadGraphic(Paths.image('storymenu/' + assetName));
				isMissing = false;
			}
		}

		if(isMissing) {
			weekThing.visible = false;
			missingFileText.visible = true;
			missingFileText.text = 'MISSING FILE: images/storymenu/' + assetName + '.png';
		}
		recalculateStuffPosition();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Week Editor", "Editting: " + weekFileName);
		#end
	}
	
	public function UIEvent(id:String, sender:Dynamic) {
		if(id == PsychUICheckBox.CLICK_EVENT)
			unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT && (sender is PsychUIInputText)) {
			if(sender == weekFileInputText) {
				weekFileName = weekFileInputText.text.trim();
				unsavedProgress = true;
				reloadWeekThing();
			} else if(sender == opponentInputText || sender == boyfriendInputText || sender == girlfriendInputText) {
				weekFile.weekCharacters[0] = opponentInputText.text.trim();
				weekFile.weekCharacters[1] = boyfriendInputText.text.trim();
				weekFile.weekCharacters[2] = girlfriendInputText.text.trim();
				unsavedProgress = true;
				updateText();
			} else if(sender == backgroundInputText) {
				weekFile.weekBackground = backgroundInputText.text.trim();
				unsavedProgress = true;
				reloadBG();
			} else if(sender == displayNameInputText) {
				weekFile.storyName = displayNameInputText.text.trim();
				unsavedProgress = true;
				updateText();
			} else if(sender == weekNameInputText) {
				weekFile.weekName = weekNameInputText.text.trim();
				unsavedProgress = true;
			} else if(sender == songsInputText) {
				var splittedText:Array<String> = songsInputText.text.trim().split(',');
				for (i in 0...splittedText.length) {
					splittedText[i] = splittedText[i].trim();
				}

				while(splittedText.length < weekFile.songs.length) {
					weekFile.songs.pop();
				}

				for (i in 0...splittedText.length) {
					if(i >= weekFile.songs.length) { //Add new song
						var song:SongData = {
							songName: splittedText[i],
							icon: 'face',
							backgroundColor: [146, 113, 253]
						};
						weekFile.songs.push(song);
					} else { //Edit song
						if (!Reflect.hasField(weekFile.songs[i], "songName") && !Reflect.hasField(weekFile.songs[i], "icon") 
							&& !Reflect.hasField(weekFile.songs[i], "backgroundColor")) {
								var icon = weekFile.songs[i][1] == null || weekFile.songs[i][1] ? 'face' : weekFile.songs[i][1];
								var bg = weekFile.songs[i][1] == null || weekFile.songs[i][1] ? [146, 113, 253] : weekFile.songs[i][2];
								var song:SongData = {
									songName: splittedText[i],
									icon: icon,
									backgroundColor: bg
								};
								weekFile.songs[i] = song;
							}
					}
				}
				updateText();
				unsavedProgress = true;
			} else if(sender == weekBeforeInputText) {
				weekFile.weekBefore = weekBeforeInputText.text.trim();
				unsavedProgress = true;
			} else if(sender == difficultiesInputText) {
				weekFile.difficulties = difficultiesInputText.text.trim();
				unsavedProgress = true;
			}
		}
	}
	
	override function update(elapsed:Float)
	{
		if(loadedWeek != null) {
			weekFile = loadedWeek;
			loadedWeek = null;

			reloadAllShit();
		}

		if(PsychUIInputText.focusOn == null)
		{
			ClientPrefs.toggleVolumeKeys(true);
			if(FlxG.keys.justPressed.ESCAPE)
			{
				if(!unsavedProgress)
				{
					MusicBeatState.switchState(new MasterEditorMenu());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				else openSubState(new ExitConfirmationPrompt(function() unsavedProgress = false));
			}
		}
		else ClientPrefs.toggleVolumeKeys(false);

		super.update(elapsed);

		lock.y = weekThing.y;
		missingFileText.y = weekThing.y + 36;
	}

	function recalculateStuffPosition() {
		weekThing.screenCenter(X);
		lock.x = weekThing.width + 10 + weekThing.x;
	}

	private static var _file:FileReference;
	public static function loadWeek() {
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');
		_file = new FileReference();
		_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file.browse([#if !mac jsonFilter #end]);
	}
	
	public static var loadedWeek:WeekFile = null;
	public static var loadError:Bool = false;
	private static function onLoadComplete(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		#if sys
		var fullPath:String = null;
		@:privateAccess
		if(_file.__path != null) fullPath = _file.__path;

		if(fullPath != null) {
			var rawJson:String = File.getContent(fullPath);
			if(rawJson != null) {
				loadedWeek = cast Json.parse(rawJson);
				if(loadedWeek.weekCharacters != null && loadedWeek.weekName != null) //Make sure it's really a week
				{
					var cutName:String = _file.name.substr(0, _file.name.length - 5);
					trace("Successfully loaded file: " + cutName);
					loadError = false;

					weekFileName = cutName;
					_file = null;
					unsavedProgress = false;
					return;
				}
			}
		}
		loadError = true;
		loadedWeek = null;
		_file = null;
		#else
		trace("File couldn't be loaded! You aren't on Desktop, are you?");
		#end
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
		private static function onLoadCancel(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		trace("Cancelled file loading.");
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private static function onLoadError(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		trace("Problem loading file");
	}

	public static function saveWeek(weekFile:WeekFile) {
		for (i in 0...weekFile.songs.length) {
			if (!Reflect.hasField(weekFile.songs[i], "songName") && !Reflect.hasField(weekFile.songs[i], "icon")  //autoconvert old format to new on save
				&& !Reflect.hasField(weekFile.songs[i], "backgroundColor")) {
					var song:SongData = {
						songName: weekFile.songs[i][0],
						icon: weekFile.songs[i][1],
						backgroundColor: weekFile.songs[i][2]
					};
					weekFile.songs[i] = song;
				}
		}
		var data:String = haxe.Json.stringify(weekFile, "\t");
		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, weekFileName + ".json");
		}
	}
	
	private static function onSaveComplete(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved file.");
		unsavedProgress = false;
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
		private static function onSaveCancel(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		trace("Cancelled file saving.");
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private static function onSaveError(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
	}
}

class WeekEditorFreeplayState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
	}

	var bg:FlxSprite;
	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<HealthIcon> = [];

	var curSelected = 0;

	override function create() {
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = FlxColor.WHITE;
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...weekFile.songs.length)
		{
			var sText = "";
			var iconName = "";
			if (!Reflect.hasField(weekFile.songs[i], "songName") && !Reflect.hasField(weekFile.songs[i], "icon") 
				&& !Reflect.hasField(weekFile.songs[i], "backgroundColor")) {
					sText = weekFile.songs[i][0];
					iconName = weekFile.songs[i][1];
				}
				
			else {
				sText = weekFile.songs[i].songName;
				iconName = weekFile.songs[i].icon;
			}
				
			var songText:Alphabet = new Alphabet(90, 320, sText, true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);
			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			var icon:HealthIcon = new HealthIcon(iconName);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}

		addEditorBox();
		changeSelection();
		super.create();
	}
	
	var UI_box:PsychUIBox;
	function addEditorBox() {
		var tabs = [
			{name: 'Freeplay', label: 'Freeplay'},
		];
		UI_box = new PsychUIBox(FlxG.width, FlxG.height, 250, 360, ['Freeplay']);
		UI_box.x -= UI_box.width + 100;
		UI_box.y -= UI_box.height + 60;
		UI_box.scrollFactor.set();
		addFreeplayUI();
		add(UI_box);

		var blackBlack:FlxSprite = new FlxSprite(0, 670).makeGraphic(FlxG.width, 50, FlxColor.BLACK);
		blackBlack.alpha = 0.6;
		add(blackBlack);

		var loadWeekButton:PsychUIButton = new PsychUIButton(0, 685, "Load Week", function() {
			WeekEditorState.loadWeek();
		});
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);
		
		var storyModeButton:PsychUIButton = new PsychUIButton(0, 685, "Story Mode", function() {
			MusicBeatState.switchState(new WeekEditorState(weekFile));
			
		});
		storyModeButton.screenCenter(X);
		add(storyModeButton);
	
		var saveWeekButton:PsychUIButton = new PsychUIButton(0, 685, "Save Week", function() {
			WeekEditorState.saveWeek(weekFile);
		});
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}
	
	public function UIEvent(id:String, sender:Dynamic)
	{
		if(id == PsychUICheckBox.CLICK_EVENT)
			WeekEditorState.unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT && (sender is PsychUIInputText))
		{
			if (sender == iconInputText) {
				if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
					&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
					{
						var song:SongData = {
							songName: weekFile.songs[curSelected][0],
							icon: iconInputText.text,
							backgroundColor: weekFile.songs[curSelected][2]
						};
						weekFile.songs[curSelected] = song;
					}
				else {
					weekFile.songs[curSelected].icon = iconInputText.text;
				}
				iconArray[curSelected].changeIcon(iconInputText.text);
			} else if (sender == diffInputText) {
				if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
					&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
					{
						var song:SongData = {
							songName: weekFile.songs[curSelected][0],
							icon: weekFile.songs[curSelected][1],
							backgroundColor: weekFile.songs[curSelected][2],
							difficulties: diffInputText.text
						};
						weekFile.songs[curSelected] = song;
					}
				else {
					weekFile.songs[curSelected].difficulties = diffInputText.text;
				}
			} else if (sender == lockSaveText) {
				if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
					&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
					{
						var song:SongData = {
							songName: weekFile.songs[curSelected][0],
							icon: weekFile.songs[curSelected][1],
							backgroundColor: weekFile.songs[curSelected][2],
							unlockedAfter: {
								save: lockSaveText.text,
								field: null
							}
						};
						weekFile.songs[curSelected] = song;
					}
				else {
					if (weekFile.songs[curSelected].unlockedAfter != null)
						weekFile.songs[curSelected].unlockedAfter.save = lockSaveText.text;
					else {
						var unlockAfter:UnlockData = {
							save: lockSaveText.text,
							field: null
						};
						weekFile.songs[curSelected].unlockedAfter = unlockAfter;
					}
				}
			} else if (sender == lockFieldText) {
				if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
					&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
					{
						var song:SongData = {
							songName: weekFile.songs[curSelected][0],
							icon: weekFile.songs[curSelected][1],
							backgroundColor: weekFile.songs[curSelected][2],
							unlockedAfter: {
								save: null,
								field: lockFieldText.text
							}
						};
						weekFile.songs[curSelected] = song;
					}
				else {
					if (weekFile.songs[curSelected].unlockedAfter != null)
						weekFile.songs[curSelected].unlockedAfter.field = lockFieldText.text;
					else {
						var unlockAfter:UnlockData = {
							save: null,
							field: lockFieldText.text
						};
						weekFile.songs[curSelected].unlockedAfter = unlockAfter;
					}
				}
			} else if (sender == showFieldText) {
				if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
					&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
					{
						var song:SongData = {
							songName: weekFile.songs[curSelected][0],
							icon: weekFile.songs[curSelected][1],
							backgroundColor: weekFile.songs[curSelected][2],
							showAfter: {
								save: showFieldText.text,
								field: null
							}
						};
						weekFile.songs[curSelected] = song;
					}
				else {
					if (weekFile.songs[curSelected].showAfter != null)
						weekFile.songs[curSelected].showAfter.save = showFieldText.text;
					else {
						var showAfter:UnlockData = {
							save: showFieldText.text,
							field: null
						};
						weekFile.songs[curSelected].showAfter = showAfter;
					}
				}
			} else if (sender == showSaveText) {
				if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
					&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
					{
						var song:SongData = {
							songName: weekFile.songs[curSelected][0],
							icon: weekFile.songs[curSelected][1],
							backgroundColor: weekFile.songs[curSelected][2],
							showAfter: {
								save: null,
								field: showSaveText.text
							}
						};
						weekFile.songs[curSelected] = song;
					}
				else {
					if (weekFile.songs[curSelected].showAfter != null)
						weekFile.songs[curSelected].showAfter.field= showSaveText.text;
					else {
						var showAfter:UnlockData = {
							save: null,
							field: showSaveText.text
						};
						weekFile.songs[curSelected].showAfter = showAfter;
					}
				}
			} else if (sender == freeplayCharacter) {
				weekFile.freeplayCharacter = freeplayCharacter.text;
			} else if (sender == linkedToText) {
				if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
					&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
					{
						var song:SongData = {
							songName: weekFile.songs[curSelected][0],
							icon: weekFile.songs[curSelected][1],
							backgroundColor: weekFile.songs[curSelected][2],
							linkedTo: linkedToText.text
						};
						weekFile.songs[curSelected] = song;
					}
				else {
					weekFile.songs[curSelected].linkedTo = linkedToText.text;
				}
			}	
		}
		else if(id == PsychUINumericStepper.CHANGE_EVENT && (sender is PsychUINumericStepper))
		{
			if(sender == bgColorStepperR || sender == bgColorStepperG || sender == bgColorStepperB)
				updateBG();
		}
	}

	var bgColorStepperR:PsychUINumericStepper;
	var bgColorStepperG:PsychUINumericStepper;
	var bgColorStepperB:PsychUINumericStepper;
	var iconInputText:PsychUIInputText;
	var diffInputText:PsychUIInputText;
	var lockSaveText:PsychUIInputText;
	var lockFieldText:PsychUIInputText;
	var showSaveText:PsychUIInputText;
	var showFieldText:PsychUIInputText;
	var freeplayCharacter:PsychUIInputText;
	var linkedToText:PsychUIInputText;
	function addFreeplayUI() {
		var tab_group = UI_box.getTab('Freeplay').menu;

		diffInputText = new PsychUIInputText(10, 40, 200, '', 8);

		freeplayCharacter = new PsychUIInputText(10, diffInputText.y + 40, 200, '', 8);

		bgColorStepperR = new PsychUINumericStepper(10, freeplayCharacter.y + 40, 20, 255, 0, 255, 0);
		bgColorStepperG = new PsychUINumericStepper(80, freeplayCharacter.y + 40, 20, 255, 0, 255, 0);
		bgColorStepperB = new PsychUINumericStepper(150, freeplayCharacter.y + 40, 20, 255, 0, 255, 0);

		var copyColor:PsychUIButton = new PsychUIButton(10, bgColorStepperR.y + 25, "Copy Color", function() Clipboard.text = bg.color.red + ',' + bg.color.green + ',' + bg.color.blue);

		var pasteColor:PsychUIButton = new PsychUIButton(140, copyColor.y, "Paste Color", function()
		{
			if(Clipboard.text != null)
			{
				var leColor:Array<Int> = [];
				var splitted:Array<String> = Clipboard.text.trim().split(',');
				for (i in 0...splitted.length)
				{
					var toPush:Int = Std.parseInt(splitted[i]);
					if(!Math.isNaN(toPush))
					{
						if(toPush > 255) toPush = 255;
						else if(toPush < 0) toPush *= -1;
						leColor.push(toPush);
					}
				}

				if(leColor.length > 2)
				{
					bgColorStepperR.value = leColor[0];
					bgColorStepperG.value = leColor[1];
					bgColorStepperB.value = leColor[2];
					updateBG();
				}
			}
		});

		iconInputText = new PsychUIInputText(10, bgColorStepperR.y + 70, 100, '', 8);

		var hideFreeplayCheckbox:PsychUICheckBox = new PsychUICheckBox(10, iconInputText.y + 30, "Hide Week from Freeplay?", 100);
		hideFreeplayCheckbox.checked = weekFile.hideFreeplay == true;
		hideFreeplayCheckbox.onClick = function()
		{
			weekFile.hideFreeplay = hideFreeplayCheckbox.checked;
			WeekEditorState.unsavedProgress = true;
		};

		lockSaveText = new PsychUIInputText(10, hideFreeplayCheckbox.y + 40, 100, '', 8);
		lockFieldText = new PsychUIInputText(lockSaveText.x + lockSaveText.width + 10, hideFreeplayCheckbox.y + 40, 100, '', 8);

		showSaveText = new PsychUIInputText(10, lockSaveText.y + 40, 100, '', 8);
		showFieldText = new PsychUIInputText(showSaveText.x + showSaveText.width + 10, lockSaveText.y + 40, 100, '', 8);

		linkedToText = new PsychUIInputText(showFieldText.x, bgColorStepperR.y + 70, 100, '', 8);
		
		tab_group.add(new FlxText(10, bgColorStepperR.y - 18, 0, 'Selected background Color R/G/B:'));
		tab_group.add(new FlxText(10, iconInputText.y - 18, 0, 'Selected icon:'));
		tab_group.add(new FlxText(10, diffInputText.y - 18, 0, 'Difficulties:'));
		tab_group.add(new FlxText(10, freeplayCharacter.y - 18, 0, 'Freeplay Character:'));
		tab_group.add(new FlxText(lockSaveText.x, lockSaveText.y - 18, 0, 'Lock Check Save File:'));
		tab_group.add(new FlxText(lockFieldText.x, lockFieldText.y - 18, 0, 'Lock Check Field:'));
		tab_group.add(new FlxText(showSaveText.x, showSaveText.y - 18, 0, 'Show Lock Save File:'));
		tab_group.add(new FlxText(showFieldText.x, showSaveText.y - 18, 0, 'Show Lock Field:'));
		tab_group.add(new FlxText(linkedToText.x, linkedToText.y - 18, 0, 'Linked To Song:'));
		tab_group.add(diffInputText);
		tab_group.add(freeplayCharacter);
		tab_group.add(bgColorStepperR);
		tab_group.add(bgColorStepperG);
		tab_group.add(bgColorStepperB);
		tab_group.add(copyColor);
		tab_group.add(pasteColor);
		tab_group.add(iconInputText);
		tab_group.add(hideFreeplayCheckbox);
		tab_group.add(lockSaveText);
		tab_group.add(lockFieldText);
		tab_group.add(showSaveText);
		tab_group.add(showFieldText);
		tab_group.add(linkedToText);
	}

	function updateBG() {
		if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
			&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor")) {
				var song:SongData = {
					icon: weekFile.songs[curSelected][1],
					songName: weekFile.songs[curSelected][0],
					backgroundColor: [Math.round(bgColorStepperR.value), Math.round(bgColorStepperG.value), Math.round(bgColorStepperB.value)]
				};
				weekFile.songs[curSelected] = song;
		} else {
			weekFile.songs[curSelected].backgroundColor = [Math.round(bgColorStepperR.value), Math.round(bgColorStepperG.value), Math.round(bgColorStepperB.value)];
		}
		bg.color = FlxColor.fromRGB(weekFile.songs[curSelected].backgroundColor[0], weekFile.songs[curSelected].backgroundColor[1], weekFile.songs[curSelected].backgroundColor[2]);
	}

	function changeSelection(change:Int = 0) {
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected = FlxMath.wrap(curSelected + change, 0, weekFile.songs.length - 1);
		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			icon.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}
		//trace(weekFile.songs[curSelected]);
		if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
			&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
			iconInputText.text = weekFile.songs[curSelected][1];
		else 
			iconInputText.text = weekFile.songs[curSelected].icon;
		

		var colors = [];
		if (!Reflect.hasField(weekFile.songs[curSelected], "songName") && !Reflect.hasField(weekFile.songs[curSelected], "icon") 
			&& !Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
			colors = weekFile.songs[curSelected][2];
		else 
			colors = weekFile.songs[curSelected].backgroundColor;
		bgColorStepperR.value = Math.round(colors[0]);
		bgColorStepperG.value = Math.round(colors[1]);
		bgColorStepperB.value = Math.round(colors[2]);
		updateBG();

		if (Reflect.hasField(weekFile.songs[curSelected], "songName") && Reflect.hasField(weekFile.songs[curSelected], "icon") 
			&& Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
			diffInputText.text = weekFile.songs[curSelected].difficulties;

		if (Reflect.hasField(weekFile.songs[curSelected], "songName") && Reflect.hasField(weekFile.songs[curSelected], "icon") 
			&& Reflect.hasField(weekFile.songs[curSelected], "backgroundColor"))
			linkedToText.text = weekFile.songs[curSelected].linkedTo;

		freeplayCharacter.text = weekFile.freeplayCharacter;

		if (Reflect.hasField(weekFile.songs[curSelected], "songName") && Reflect.hasField(weekFile.songs[curSelected], "icon") 
			&& Reflect.hasField(weekFile.songs[curSelected], "backgroundColor")) {
			if (weekFile.songs[curSelected].unlockedAfter != null)
			{
				lockSaveText.text = weekFile.songs[curSelected].unlockedAfter.save;
				lockFieldText.text = weekFile.songs[curSelected].unlockedAfter.field;
			}
		}

		if (Reflect.hasField(weekFile.songs[curSelected], "songName") && Reflect.hasField(weekFile.songs[curSelected], "icon") 
			&& Reflect.hasField(weekFile.songs[curSelected], "backgroundColor")) {
			if (weekFile.songs[curSelected].showAfter != null)
			{
				showSaveText.text = weekFile.songs[curSelected].showAfter.save;
				showFieldText.text = weekFile.songs[curSelected].showAfter.field;
			}
		}
	}

	override function update(elapsed:Float) {
		if(WeekEditorState.loadedWeek != null) {
			super.update(elapsed);
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new WeekEditorFreeplayState(WeekEditorState.loadedWeek));
			WeekEditorState.loadedWeek = null;
			return;
		}
		
		if(PsychUIInputText.focusOn != null)
			ClientPrefs.toggleVolumeKeys(false);
		else
		{
			ClientPrefs.toggleVolumeKeys(true);
			if(FlxG.keys.justPressed.ESCAPE) {
				if(!WeekEditorState.unsavedProgress)
				{
					MusicBeatState.switchState(new MasterEditorMenu());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				else openSubState(new ExitConfirmationPrompt());
			}

			if(controls.UI_UP_P) changeSelection(-1);
			if(controls.UI_DOWN_P) changeSelection(1);
		}
		super.update(elapsed);
	}
}
