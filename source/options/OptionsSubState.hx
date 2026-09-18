package options;

import haxe.Json;

import flixel.FlxSubState;
import objects.Note;
import shaders.RGBPalette;
import substates.PauseSubState;

class OptionsSubState extends MusicBeatSubstate
{
	public static var instance(default, null):OptionsSubState;
	public static var fromPause(get, never):Bool;
	static function get_fromPause():Bool
		return instance != null && instance.pauseMenu != null;

	public static var returnToPlayState:Bool = false;
	static var lastSelected:Int = 0;
	var options:Array<String> = [
		'Note Colors', 'Controls', 'Adjust Delay and Combo', 'Graphics', 'Visuals', 'Gameplay'
		#if TRANSLATIONS_ALLOWED , 'Language' #end
	];
	var grpOptions:FlxTypedGroup<Alphabet>;
	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;
	var warning:FlxText;
	var curSelected:Int;
	var pauseMenu:MusicBeatSubstate;
	var session:OptionsSession;
	var savedShaders:Array<RGBPalette>;
	var savedStageUI:String;
	var restoredContext:Bool = false;
	var leaving:Bool = false;
	var transitionIn:Bool;
	var previousTweens:Array<FlxTween>;

	public function new(?pauseMenu:MusicBeatSubstate, transitionIn:Bool = false)
	{
		super();
		this.pauseMenu = pauseMenu;
		this.transitionIn = transitionIn;
		instance = this;
		persistentUpdate = false;
		curSelected = lastSelected;
		if (pauseMenu != null)
		{
			cameras = pauseMenu.cameras;
			session = new OptionsSession();
			savedShaders = Note.globalRgbShaders;
			Note.globalRgbShaders = [];
			savedStageUI = PlayState.stageUI;
		}
	}

	public static function createBackground():FlxSprite
	{
		var bg:FlxSprite;
		if (fromPause)
		{
			bg = new FlxSprite().makeGraphic(1, 1, FlxColor.GRAY);
			bg.scale.set(FlxG.width, FlxG.height);
			bg.updateHitbox();
			bg.alpha = 0.8;
		}
		else
		{
			bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
			bg.color = 0xFFea71fd;
			bg.antialiasing = ClientPrefs.data.antialiasing;
			bg.screenCenter();
		}
		bg.scrollFactor.set();
		return bg;
	}

	public static function restartWarning():String
		return Language.getPhrase('options_restart_required', 'Changing this setting requires restarting the song.');

	override function create()
	{
		add(createBackground());
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);
		for (option in options)
			grpOptions.add(new Alphabet(0, 0, '', true));
		selectorLeft = new Alphabet(0, 0, '>', true);
		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorLeft);
		add(selectorRight);
		warning = new FlxText(40, FlxG.height - 45, FlxG.width - 80, '', 20);
		warning.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
		add(warning);
		refreshLabels();
		super.create();
		if (transitionIn) openSubState(new CustomFadeTransition(0.5, true));
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Options Menu', null);
		#end
	}

	function refreshLabels()
	{
		for (i => item in grpOptions.members)
		{
			item.text = Language.getPhrase('options_${options[i]}', options[i]);
			item.screenCenter();
			item.y += 92 * (i - options.length / 2) + 45;
		}
		changeSelection();
	}

	function openSelectedSubstate(label:String)
	{
		if (label == 'Adjust Delay and Combo')
		{
			leaving = true;
			ClientPrefs.saveSettings();
			returnToPlayState = fromPause;
			if (fromPause)
			{
				PlayState.instance.canResync = false;
				restoreGameplayContext();
			}
			MusicBeatState.switchState(new NoteOffsetState());
			return;
		}
		previousTweens = [];
		FlxTween.globalManager.forEach(tween -> previousTweens.push(tween));
		var menu:FlxSubState = switch (label)
		{
			case 'Note Colors': new NotesColorSubState();
			case 'Controls': new ControlsSubState();
			case 'Graphics': new GraphicsSettingsSubState();
			case 'Visuals': new VisualsSettingsSubState();
			case 'Gameplay': new GameplaySettingsSubState();
			case 'Language': new LanguageSubState();
			default: null;
		};
		if (menu != null)
		{
			persistentDraw = false;
			menu.cameras = cameras;
			openSubState(menu);
		}
	}

	override public function resetSubState()
	{
		if (subState != null) clearMenuTweens();
		super.resetSubState();
		if (subState == null && !leaving)
		{
			persistentDraw = true;
			if (pauseMenu != null) PlayState.stageUI = savedStageUI;
			ClientPrefs.saveSettings();
			#if DISCORD_ALLOWED
			if (ClientPrefs.data.discordRPC) DiscordClient.changePresence('Options Menu', null);
			#end
			refreshLabels();
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (leaving) return;
		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);
		if (controls.BACK)
		{
			leaving = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			ClientPrefs.saveSettings();
			if (session != null)
			{
				restoreGameplayContext();
				if (session.needsRestart())
				{
					PlayState.nextReloadAll = true;
					PauseSubState.restartSong();
				}
				else
				{
					PlayState.instance.applyOptions(session);
					close();
				}
			}
			else MusicBeatState.switchState(new states.MainMenuState());
		}
		else if (controls.ACCEPT) openSelectedSubstate(options[curSelected]);
	}

	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		lastSelected = curSelected;
		for (i => item in grpOptions.members)
		{
			item.alpha = i == curSelected ? 1 : 0.6;
			if (i == curSelected)
			{
				selectorLeft.setPosition(item.x - 63, item.y);
				selectorRight.setPosition(item.x + item.width + 15, item.y);
			}
		}
		warning.text = fromPause && ['Note Colors', 'Adjust Delay and Combo', 'Language'].contains(options[curSelected])
			? restartWarning() : '';
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	public function previewPauseMusic()
	{
		if (Std.isOfType(pauseMenu, PauseSubState)) (cast pauseMenu:PauseSubState).reloadPauseMusic();
	}

	function restoreGameplayContext()
	{
		if (pauseMenu == null || restoredContext) return;
		if (PlayState.instance != null)
		{
			Note.globalRgbShaders = savedShaders;
			PlayState.stageUI = savedStageUI;
		}
		restoredContext = true;
	}

	function clearMenuTweens()
	{
		if (previousTweens == null) return;
		var toCancel:Array<FlxTween> = [];
		FlxTween.globalManager.forEach(function(tween:FlxTween)
		{
			if (!previousTweens.contains(tween)) toCancel.push(tween);
		});
		for (tween in toCancel) tween.cancel();
		previousTweens = null;
	}

	override function destroy()
	{
		clearMenuTweens();
		super.destroy();
		restoreGameplayContext();
		if (instance == this) instance = null;
	}
}

class OptionsSession
{
	static final restartFields:Array<String> = [
		'arrowRGB', 'arrowRGBPixel', 'noteOffset', 'comboOffset',
		'lowQuality', 'antialiasing', 'shaders', 'cacheOnGPU', 'hideHud', 'flashing',
		'downScroll', 'middleScroll', 'opponentStrums', 'enableModcharts', 'enableMechanics',
		'guitarHeroSustains', 'developerMode', 'language'
	];

	var initialValues:Map<String, String> = [];

	public function new()
	{
		for (field in Reflect.fields(ClientPrefs.data))
			initialValues.set(field, Json.stringify(Reflect.field(ClientPrefs.data, field)));
	}

	public static function requiresRestart(field:String):Bool
		return restartFields.contains(field);

	public function changedFields():Array<String>
	{
		return [for (field => value in initialValues)
			if (Json.stringify(Reflect.field(ClientPrefs.data, field)) != value) field];
	}

	public function needsRestart():Bool
	{
		for (field in changedFields())
			if (requiresRestart(field)) return true;
		return false;
	}

	public function previousValue(field:String):Dynamic
		return initialValues.exists(field) ? Json.parse(initialValues.get(field)) : null;
}
