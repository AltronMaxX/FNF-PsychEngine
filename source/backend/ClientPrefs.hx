package backend;

import haxe.Json;
import openfl.utils.Assets;

import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

import states.TitleState;

// Add a variable here and it will get automatically saved
@:structInit class SaveVariables {
	public var downScroll:Bool = false;
	public var middleScroll:Bool = false;
	public var opponentStrums:Bool = true;
	public var showFPS:Bool = true;
	public var flashing:Bool = true;
	public var autoPause:Bool = true;
	public var antialiasing:Bool = true;
	public var noteSkin:String = 'Default';
	public var splashSkin:String = 'Psych';
	public var splashAlpha:Float = 0.6;
	public var holdCoverAlpha:Float = 1;
	public var holdSplashAlpha:Float = 0.6;
	public var lowQuality:Bool = false;
	public var shaders:Bool = true;
	public var cacheOnGPU:Bool = #if !switch false #else true #end; // GPU Caching made by Raltyro
	public var framerate:Int = 60;
	public var camZooms:Bool = true;
	public var hideHud:Bool = false;
	public var noteOffset:Int = 0;
	public var arrowRGB:Array<Array<FlxColor>> = [
		[0xFFC24B99, 0xFFFFFFFF, 0xFF3C1F56],
		[0xFF00FFFF, 0xFFFFFFFF, 0xFF1542B7],
		[0xFF12FA05, 0xFFFFFFFF, 0xFF0A4447],
		[0xFFF9393F, 0xFFFFFFFF, 0xFF651038]];
	public var arrowRGBPixel:Array<Array<FlxColor>> = [
		[0xFFE276FF, 0xFFFFF9FF, 0xFF60008D],
		[0xFF3DCAFF, 0xFFF4FFFF, 0xFF003060],
		[0xFF71E300, 0xFFF6FFE6, 0xFF003100],
		[0xFFFF884E, 0xFFFFFAF5, 0xFF6C0000]];

	public var ghostTapping:Bool = true;
	public var timeBarType:String = 'Time Left';
	public var scoreZoom:Bool = true;
	public var noReset:Bool = false;
	public var healthBarAlpha:Float = 1;
	public var hitsoundVolume:Float = 0;
	public var pauseMusic:String = 'Tea Time';
	public var checkForUpdates:Bool = true;
	public var comboStacking:Bool = true;
	public var developerMode:Bool = false;
	public var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'scrolltype' => 'multiplicative', 
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		// -kade
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'instakill' => false,
		'practice' => false,
		'botplay' => false,
		'opponentplay' => false
	];

	public var comboOffset:Array<Int> = [0, 0, 0, 0];
	public var ratingOffset:Int = 0;
	public var sickWindow:Float = 45.0;
	public var goodWindow:Float = 90.0;
	public var badWindow:Float = 135.0;
	public var safeFrames:Float = 10.0;
	public var guitarHeroSustains:Bool = true;
	public var discordRPC:Bool = true;
	public var loadingScreen:Bool = true;
	public var language:String = 'en-US';
	public var enableModcharts:Bool = true;
	public var enableMechanics:Bool = true;
}

class ClientPrefs {
	public static var data:SaveVariables = {};
	public static var defaultData:SaveVariables = {};

	//Every key has two binds, add your key bind down here and then add your control on options/ControlsSubState.hx and Controls.hx
	public static var keyBinds:Map<String, Array<FlxKey>> = [
		//Key Bind, Name for ControlsSubState
		'note_up'		=> [W, UP],
		'note_left'		=> [A, LEFT],
		'note_down'		=> [S, DOWN],
		'note_right'	=> [D, RIGHT],
		
		'ui_up'			=> [W, UP],
		'ui_left'		=> [A, LEFT],
		'ui_down'		=> [S, DOWN],
		'ui_right'		=> [D, RIGHT],
		'ui_prev'		=> [Z],
		'ui_next'		=> [X],
		
		'accept'		=> [SPACE, ENTER],
		'back'			=> [BACKSPACE, ESCAPE],
		'pause'			=> [ENTER, ESCAPE],
		'reset'			=> [R],
		
		'volume_mute'	=> [ZERO],
		'volume_up'		=> [NUMPADPLUS, PLUS],
		'volume_down'	=> [NUMPADMINUS, MINUS],
		
		'debug_1'		=> [SEVEN],
		'debug_2'		=> [EIGHT]
	];
	public static var gamepadBinds:Map<String, Array<FlxGamepadInputID>> = [
		'note_up'		=> [DPAD_UP, Y],
		'note_left'		=> [DPAD_LEFT, X],
		'note_down'		=> [DPAD_DOWN, A],
		'note_right'	=> [DPAD_RIGHT, B],
		
		'ui_up'			=> [DPAD_UP, LEFT_STICK_DIGITAL_UP],
		'ui_left'		=> [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
		'ui_down'		=> [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
		'ui_right'		=> [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
		
		'accept'		=> [A, START],
		'back'			=> [B],
		'pause'			=> [START],
		'reset'			=> [BACK]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;
	public static var defaultButtons:Map<String, Array<FlxGamepadInputID>> = null;

	public static function resetKeys(controller:Null<Bool> = null) //Null = both, False = Keyboard, True = Controller
	{
		if(controller != true)
			for (key in keyBinds.keys())
				if(defaultKeys.exists(key))
					keyBinds.set(key, defaultKeys.get(key).copy());

		if(controller != false)
			for (button in gamepadBinds.keys())
				if(defaultButtons.exists(button))
					gamepadBinds.set(button, defaultButtons.get(button).copy());
	}

	public static function clearInvalidKeys(key:String)
	{
		var keyBind:Array<FlxKey> = keyBinds.get(key);
		var gamepadBind:Array<FlxGamepadInputID> = gamepadBinds.get(key);
		while(keyBind != null && keyBind.contains(NONE)) keyBind.remove(NONE);
		while(gamepadBind != null && gamepadBind.contains(NONE)) gamepadBind.remove(NONE);
	}

	public static function loadDefaultKeys()
	{
		defaultKeys = keyBinds.copy();
		defaultButtons = gamepadBinds.copy();
	}

	public static function saveSettings() {
		for (key in Reflect.fields(data))
			Reflect.setField(FlxG.save.data, key, Reflect.field(data, key));
		VisualOptions.savePreferences(FlxG.save.data);

		#if ACHIEVEMENTS_ALLOWED Achievements.save(); #end
		FlxG.save.flush();

		//Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
		var save:FlxSave = new FlxSave();
		save.bind('controls_v3', CoolUtil.getSavePath());
		save.data.keyboard = keyBinds;
		save.data.gamepad = gamepadBinds;
		save.flush();
		FlxG.log.add("Settings saved!");
	}

	public static function loadPrefs() {
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

		for (key in Reflect.fields(data))
			if (key != 'gameplaySettings' && Reflect.hasField(FlxG.save.data, key))
				Reflect.setField(data, key, Reflect.field(FlxG.save.data, key));
		VisualOptions.loadPreferences(FlxG.save.data);
		
		if(Main.fpsVar != null)
			Main.fpsVar.visible = data.showFPS;

		#if (!html5 && !switch)
		FlxG.autoPause = ClientPrefs.data.autoPause;

		if(FlxG.save.data.framerate == null) {
			final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
			data.framerate = Std.int(FlxMath.bound(refreshRate, 60, 240));
		}
		#end

		if(data.framerate > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = data.framerate;
			FlxG.drawFramerate = data.framerate;
		}
		else
		{
			FlxG.drawFramerate = data.framerate;
			FlxG.updateFramerate = data.framerate;
		}

		if(FlxG.save.data.gameplaySettings != null)
		{
			var savedMap:Map<String, Dynamic> = FlxG.save.data.gameplaySettings;
			for (name => value in savedMap)
				data.gameplaySettings.set(name, value);
		}
		
		// flixel automatically saves your volume!
		if(FlxG.save.data.volume != null)
			FlxG.sound.volume = FlxG.save.data.volume;
		if (FlxG.save.data.mute != null)
			FlxG.sound.muted = FlxG.save.data.mute;

		#if DISCORD_ALLOWED DiscordClient.check(); #end

		// controls on a separate save file
		var save:FlxSave = new FlxSave();
		save.bind('controls_v3', CoolUtil.getSavePath());
		if(save != null)
		{
			if(save.data.keyboard != null)
			{
				var loadedControls:Map<String, Array<FlxKey>> = save.data.keyboard;
				for (control => keys in loadedControls)
					if(keyBinds.exists(control)) keyBinds.set(control, keys);
			}
			if(save.data.gamepad != null)
			{
				var loadedControls:Map<String, Array<FlxGamepadInputID>> = save.data.gamepad;
				for (control => keys in loadedControls)
					if(gamepadBinds.exists(control)) gamepadBinds.set(control, keys);
			}
			reloadVolumeKeys();
		}
	}

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic = null, ?customDefaultValue:Bool = false):Dynamic
	{
		if(!customDefaultValue) defaultValue = defaultData.gameplaySettings.get(name);
		return /*PlayState.isStoryMode ? defaultValue : */ (data.gameplaySettings.exists(name) ? data.gameplaySettings.get(name) : defaultValue);
	}

	public static function reloadVolumeKeys()
	{
		TitleState.muteKeys = keyBinds.get('volume_mute').copy();
		TitleState.volumeDownKeys = keyBinds.get('volume_down').copy();
		TitleState.volumeUpKeys = keyBinds.get('volume_up').copy();
		toggleVolumeKeys(true);
	}
	public static function toggleVolumeKeys(?turnOn:Bool = true)
	{
		final emptyArray = [];
		FlxG.sound.muteKeys = turnOn ? TitleState.muteKeys : emptyArray;
		FlxG.sound.volumeDownKeys = turnOn ? TitleState.volumeDownKeys : emptyArray;
		FlxG.sound.volumeUpKeys = turnOn ? TitleState.volumeUpKeys : emptyArray;
	}
}

class VisualOptions
{
	static final fields:Array<String> = ['noteSkin', 'splashSkin', 'pauseMusic'];
	static var values:Map<String, Array<String>> = [];
	static var defaults:Map<String, String> = [];
	static var selections:Map<String, String> = [];
	static var loadedContext:String = null;
	static var preferencesLoaded:Bool = false;

	public static function reload(force:Bool = false)
	{
		var context:String = Json.stringify({mod: Mods.currentModDirectory, globals: Mods.getGlobalMods(), level: Paths.currentLevel});
		if (!force && loadedContext == context) return;
		loadedContext = context;
		values = [
			'noteSkin' => [ClientPrefs.defaultData.noteSkin],
			'splashSkin' => [ClientPrefs.defaultData.splashSkin],
			'pauseMusic' => ['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)']
		];
		defaults.clear();
		for (field in fields)
			defaults.set(field, Reflect.field(ClientPrefs.defaultData, field));
		appendValues('noteSkin', Mods.mergeAllTextsNamed('images/noteSkins/list.txt'));
		appendValues('splashSkin', Mods.mergeAllTextsNamed('images/noteSplashes/list.txt'));

		for (path in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/visualOptions.json'))
		{
			try
			{
				var contents:String = #if sys File.getContent(path) #else Assets.getText(path) #end;
				var config:Dynamic = Json.parse(contents);
				if (!isObject(config)) throw 'Expected an object';
				for (field in fields)
				{
					var section:Dynamic = Reflect.field(config, field);
					if (section == null) continue;
					if (!isObject(section))
					{
						trace('$path: invalid $field section');
						continue;
					}
					var additions:Array<String> = [];
					var entries:Dynamic = Reflect.field(section, 'values');
					if (Std.isOfType(entries, Array))
					{
						for (entry in (cast entries:Array<Dynamic>))
						{
							var name:String = stringValue(entry);
							if (name != null && !additions.contains(name)) additions.push(name);
						}
					}
					for (name in values.get(field))
						if (!additions.contains(name)) additions.push(name);
					values.set(field, additions);
					var defaultName:String = stringValue(Reflect.field(section, 'default'));
					if (defaultName != null)
					{
						if (additions.contains(defaultName)) defaults.set(field, defaultName);
						else trace('$path: unknown default for $field: $defaultName');
					}
				}
			}
			catch (e:Dynamic)
			{
				trace('Could not load $path: $e');
			}
		}
		if (preferencesLoaded) applyPreferences();
	}

	static function appendValues(field:String, entries:Array<String>)
	{
		var list:Array<String> = values.get(field);
		for (entry in entries)
			if (!list.contains(entry)) list.push(entry);
	}

	static function isObject(value:Dynamic):Bool
		return value != null && Reflect.isObject(value) && !Std.isOfType(value, String) && !Std.isOfType(value, Array);

	static function stringValue(value:Dynamic):String
	{
		if (!Std.isOfType(value, String)) return null;
		var text:String = StringTools.trim(cast value);
		return text.length > 0 ? text : null;
	}

	public static function getValues(field:String):Array<String>
	{
		reload();
		return values.exists(field) ? values.get(field).copy() : [];
	}

	public static function getDefault(field:String):String
	{
		if (!fields.contains(field)) return null;
		reload();
		return defaults.get(field);
	}

	public static function loadPreferences(save:Dynamic)
	{
		preferencesLoaded = false;
		reload(true);
		selections.clear();
		var savedSelections:Dynamic = Reflect.field(save, 'visualOptionsSelections');
		var migrated:Bool = isObject(savedSelections);
		for (field in fields)
		{
			var selection:String = stringValue(Reflect.field(migrated ? savedSelections : save, field));
			if (selection != null && (migrated || selection != Reflect.field(ClientPrefs.defaultData, field)))
				selections.set(field, selection);
		}
		preferencesLoaded = true;
		applyPreferences();
	}

	static function applyPreferences()
	{
		for (field in fields)
		{
			var selection:String = selections.get(field);
			if (selection == null || !values.get(field).contains(selection)) selection = defaults.get(field);
			Reflect.setField(ClientPrefs.data, field, selection);
		}
	}

	public static function rememberSelection(field:String)
	{
		if (!fields.contains(field)) return;
		var selection:String = stringValue(Reflect.field(ClientPrefs.data, field));
		if (selection != null) selections.set(field, selection);
	}

	public static function savePreferences(save:Dynamic)
	{
		var savedSelections:Dynamic = {};
		for (field => selection in selections)
			Reflect.setField(savedSelections, field, selection);
		Reflect.setField(save, 'visualOptionsSelections', savedSelections);
	}
}
