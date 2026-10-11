package options;

import backend.InputFormatter;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import objects.AttachedSprite;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepadManager;

class ControlsSubState extends MusicBeatSubstate
{
	var curSelected:Int = 0;
	var curAlt:Bool = false;
	var noteBindings:NoteBindings;

	//Show on gamepad - Display name - Save file key - Rebind display name
	var options:Array<Dynamic> = [
		[true, 'NOTES'],
		[true],
		[true],
		[true, '', '__notes_primary', 'Notes'],
		[true, '', '__notes_alternate', 'Notes'],
		[true],
		[true, 'UI'],
		[true, 'Left', 'ui_left', 'UI Left'],
		[true, 'Down', 'ui_down', 'UI Down'],
		[true, 'Up', 'ui_up', 'UI Up'],
		[true, 'Right', 'ui_right', 'UI Right'],
		[true, 'Prev', 'ui_prev', 'UI Prev'],
		[true, 'Next', 'ui_next', 'UI Next'],
		[true],
		[true, 'Reset', 'reset', 'Reset'],
		[true, 'Accept', 'accept', 'Accept'],
		[true, 'Back', 'back', 'Back'],
		[true, 'Pause', 'pause', 'Pause'],
		[false],
		[false, 'VOLUME'],
		[false, 'Mute', 'volume_mute', 'Volume Mute'],
		[false, 'Up', 'volume_up', 'Volume Up'],
		[false, 'Down', 'volume_down', 'Volume Down'],
		[false],
		[false, 'DEBUG'],
		[false, 'Key 1', 'debug_1', 'Debug Key #1'],
		[false, 'Key 2', 'debug_2', 'Debug Key #2']
	];
	var curOptions:Array<Int>;
	var curOptionsValid:Array<Int>;
	static var defaultKey:String = 'Reset to Default Keys';

	var bg:FlxSprite;
	var grpDisplay:FlxTypedGroup<Alphabet>;
	var grpBlacks:FlxTypedGroup<AttachedSprite>;
	var grpOptions:FlxTypedGroup<Alphabet>;
	var grpBinds:FlxTypedGroup<Alphabet>;
	var selectSpr:AttachedSprite;

	var gamepadColor:FlxColor = 0xfffd7194;
	var keyboardColor:FlxColor = 0xff7192fd;
	var onKeyboardMode:Bool = true;
	
	var controllerSpr:FlxSprite;
	
	public function new()
	{
		super();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Controls Menu", null);
		#end

		options.push([true]);
		options.push([true]);
		options.push([true, defaultKey]);

		bg = OptionsSubState.createBackground();
		if (OptionsSubState.fromPause)
		{
			// Tint a white surface, not the shared gray pause overlay.
			bg.makeGraphic(1, 1, FlxColor.WHITE);
			bg.scale.set(FlxG.width, FlxG.height);
			bg.updateHitbox();
			bg.alpha = 0.95;
			keyboardColor = 0xFF9DB6FF;
		}
		bg.color = keyboardColor;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);

		var grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.velocity.set(40, 40);
		grid.alpha = 0;
		FlxTween.tween(grid, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		add(grid);

		grpDisplay = new FlxTypedGroup<Alphabet>();
		add(grpDisplay);
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);
		grpBlacks = new FlxTypedGroup<AttachedSprite>();
		add(grpBlacks);
		noteBindings = new NoteBindings();
		if (OptionsSubState.fromPause) noteBindings.keys = KeyMode.songKeys();
		add(noteBindings);
		add(noteBindings.bubbles);
		selectSpr = new AttachedSprite();
		selectSpr.makeGraphic(250, 78, FlxColor.WHITE);
		selectSpr.copyAlpha = false;
		selectSpr.alpha = 0.75;
		add(selectSpr);
		add(noteBindings.keyLabels);
		grpBinds = new FlxTypedGroup<Alphabet>();
		add(grpBinds);

		controllerSpr = new FlxSprite(50, 40).loadGraphic(Paths.image('controllertype'), true, 82, 60);
		controllerSpr.antialiasing = ClientPrefs.data.antialiasing;
		controllerSpr.animation.add('keyboard', [0], 1, false);
		controllerSpr.animation.add('gamepad', [1], 1, false);
		add(controllerSpr);

		var text:Alphabet = new Alphabet(60, 90, 'CTRL', false);
		text.alignment = CENTERED;
		text.setScale(0.4);
		add(text);

		controllerSpr.animation.play('keyboard');
		createTexts();
	}

	var lastID:Int = 0;
	function createTexts()
	{
		curOptions = [];
		curOptionsValid = [];
		grpDisplay.forEachAlive(function(text:Alphabet) text.destroy());
		grpBlacks.forEachAlive(function(black:AttachedSprite) black.destroy());
		grpOptions.forEachAlive(function(text:Alphabet) text.destroy());
		grpBinds.forEachAlive(function(text:Alphabet) text.destroy());
		grpDisplay.clear();
		grpBlacks.clear();
		grpOptions.clear();
		grpBinds.clear();

		var myID:Int = 0;
		for (i => option in options)
		{
			if(onKeyboardMode || option[0])
			{
				if(option.length > 1)
				{
					var isCentered:Bool = (option.length < 3);
					var isDefaultKey:Bool = (option[1] == defaultKey);
					var isDisplayKey:Bool = (isCentered && !isDefaultKey);

					var str:String = option[1];
					var keyStr:String = option[2];
					if(isDefaultKey) str = Language.getPhrase(str);
					var text:Alphabet = new Alphabet(475, 300, !isDisplayKey ? Language.getPhrase('key_$keyStr', str) : Language.getPhrase('keygroup_$str', str), !isDisplayKey);
					text.isMenuItem = true;
					text.changeX = false;
					text.distancePerItem.y = 60;
					text.targetY = myID;
					text.ID = myID;
					lastID = myID;

					if(!isDisplayKey)
					{
						text.alignment = RIGHT;
						grpOptions.add(text);
						curOptions.push(i);
						curOptionsValid.push(myID);
					}
					else grpDisplay.add(text);

					if(isCentered) addCenteredText(text, option, myID);
					else addKeyText(text, option, myID);

					text.snapToPosition();
					text.y += FlxG.height * 2;
				}
				myID++;
			}
		}
		noteBindings.keyboard = onKeyboardMode;
		noteBindings.rebuild();
		updateText();
	}

	function addCenteredText(text:Alphabet, option:Array<Dynamic>, id:Int)
	{
		text.alignment = LEFT;
		text.screenCenter(X);
		text.y -= 55;
		text.startPosition.y -= 55;
		if (option[1] == 'NOTES') { text.y -= 55; text.startPosition.y -= 55; }
	}
	function addKeyText(text:Alphabet, option:Array<Dynamic>, id:Int)
	{
		if (StringTools.startsWith(option[2], '__notes_'))
		{
			// Two selectable rows, while all original option/bind indexes stay paired.
			text.visible = false;
			for (n in 0...2) {
				var placeholder = new Alphabet(0, 0, ''); placeholder.visible = false;
				placeholder.ID = Math.floor(grpBinds.length / 2); grpBinds.add(placeholder);
				var black = new AttachedSprite(); black.visible = false; grpBlacks.add(black);
			}
			return;
		}
		var keys:Array<Null<FlxKey>> = ClientPrefs.keyBinds.get(option[2]);
		if(keys == null && onKeyboardMode)
			keys = ClientPrefs.defaultKeys.get(option[2]).copy();

		var gmpds:Array<Null<FlxGamepadInputID>> = ClientPrefs.gamepadBinds.get(option[2]);
		if(gmpds == null && !onKeyboardMode)
			gmpds = ClientPrefs.defaultButtons.get(option[2]).copy();

		for (n in 0...2)
		{
			var key:String = null;
			if(onKeyboardMode)
				key = InputFormatter.getKeyName((keys[n] != null) ? keys[n] : NONE);
			else
				key = InputFormatter.getGamepadName((gmpds[n] != null) ? gmpds[n] : NONE);

			var attach:Alphabet = new Alphabet(560 + n * 300, 248, key, false);
			attach.isMenuItem = true;
			attach.changeX = false;
			attach.distancePerItem.y = 60;
			attach.targetY = text.targetY;
			attach.ID = Math.floor(grpBinds.length / 2);
			attach.snapToPosition();
			attach.y += FlxG.height * 2;
			grpBinds.add(attach);

			playstationCheck(attach);
			attach.scaleX = Math.min(1, 230 / attach.width);
			//attach.text = key;

			// spawn black bars at the right of the key name
			var black:AttachedSprite = new AttachedSprite();
			black.makeGraphic(250, 78, FlxColor.BLACK);
			black.alphaMult = 0.4;
			black.sprTracker = text;
			black.yAdd = -6;
			black.xAdd = 75 + n * 300;
			grpBlacks.add(black);
		}
	}

	function playstationCheck(alpha:Alphabet)
	{
		if(onKeyboardMode) return;

		var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
		var model:FlxGamepadModel = gamepad != null ? gamepad.detectedModel : UNKNOWN;
		var letter = alpha.letters[0];
		if(model == PS4)
		{
			switch(alpha.text)
			{
				case '[', ']': //Square and Triangle respectively
					letter.image = 'alphabet_playstation';
					letter.updateHitbox();
					
					letter.offset.x += 4;
					letter.offset.y -= 5;
			}
		}
	}

	function updateBind(num:Int, text:String)
	{
		if (num < 4) { noteBindings.rebuild(); return; }
		var bind:Alphabet = grpBinds.members[num];
		var attach:Alphabet = new Alphabet(350 + (num % 2) * 300, 248, text, false);
		attach.isMenuItem = true;
		attach.changeX = false;
		attach.distancePerItem.y = 60;
		attach.targetY = bind.targetY;
		attach.ID = bind.ID;
		attach.x = bind.x;
		attach.y = bind.y;
		
		playstationCheck(attach);
		attach.scaleX = Math.min(1, 230 / attach.width);
		//attach.text = text;

		bind.kill();
		grpBinds.remove(bind);
		grpBinds.insert(num, attach);
		bind.destroy();
	}

	var binding:Bool = false;
	var holdingEsc:Float = 0;
	var bindingBlack:FlxSprite;
	var bindingText:Alphabet;
	var bindingText2:Alphabet;

	var timeForMoving:Float = 0.1;
	override function update(elapsed:Float)
	{
		if(timeForMoving > 0) //Fix controller bug
		{
			timeForMoving = Math.max(0, timeForMoving - elapsed);
			super.update(elapsed);
			positionNotes();
			return;
		}

		if(!binding)
		{
			if(FlxG.keys.justPressed.ESCAPE || FlxG.gamepads.anyJustPressed(B))
			{
				close();
				return;
			}
			if(FlxG.keys.justPressed.CONTROL || (curSelected >= 2 && (FlxG.gamepads.anyJustPressed(LEFT_SHOULDER) || FlxG.gamepads.anyJustPressed(RIGHT_SHOULDER)))) swapMode();
			if (curSelected < 2) {
				if (controls.UI_PREV_P) changeKeys(-1);
				else if (controls.UI_NEXT_P) changeKeys(1);
			}

			if(FlxG.keys.justPressed.LEFT || FlxG.gamepads.anyJustPressed(DPAD_LEFT) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_LEFT)) moveHorizontal(-1);
			else if(FlxG.keys.justPressed.RIGHT || FlxG.gamepads.anyJustPressed(DPAD_RIGHT) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_RIGHT)) moveHorizontal(1);

			if(FlxG.keys.justPressed.UP || FlxG.gamepads.anyJustPressed(DPAD_UP) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_UP)) updateText(-1);
			else if(FlxG.keys.justPressed.DOWN || FlxG.gamepads.anyJustPressed(DPAD_DOWN) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_DOWN)) updateText(1);

			if(FlxG.keys.justPressed.ENTER || FlxG.gamepads.anyJustPressed(START) || FlxG.gamepads.anyJustPressed(A))
			{
				if(options[curOptions[curSelected]][1] != defaultKey)
				{
					bindingBlack = new FlxSprite().makeGraphic(1, 1, /*FlxColor.BLACK*/ FlxColor.WHITE);
					bindingBlack.scale.set(FlxG.width, FlxG.height);
					bindingBlack.updateHitbox();
					bindingBlack.alpha = 0;
					FlxTween.tween(bindingBlack, {alpha: 0.6}, 0.35, {ease: FlxEase.linear});
					add(bindingBlack);

					bindingText = new Alphabet(FlxG.width / 2, 160, Language.getPhrase('controls_rebinding', 'Rebinding {1}', [currentOption()[3]]), false);
					bindingText.alignment = CENTERED;
					add(bindingText);
					
					bindingText2 = new Alphabet(FlxG.width / 2, 340, Language.getPhrase('controls_rebinding2', 'Hold ESC to Cancel\nHold Backspace to Delete'), true);
					bindingText2.alignment = CENTERED;
					add(bindingText2);

					binding = true;
					holdingEsc = 0;
					ClientPrefs.toggleVolumeKeys(false);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
				else
				{
					// Reset to Default
					ClientPrefs.resetKeys(!onKeyboardMode);
					ClientPrefs.reloadVolumeKeys();
					var lastSel:Int = curSelected;
					createTexts();
					curSelected = lastSel;
					updateText();
					FlxG.sound.play(Paths.sound('cancelMenu'));
				}
			}
		}
		else
		{
			var altNum:Int = curSelected < 2 ? curSelected : (curAlt ? 1 : 0);
			var curOption:Array<Dynamic> = currentOption();
			if(FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(B))
			{
				holdingEsc += elapsed;
				if(holdingEsc > 0.5)
				{
					FlxG.sound.play(Paths.sound('cancelMenu'));
					closeBinding();
				}
			}
			else if (FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(BACK))
			{
				holdingEsc += elapsed;
				if(holdingEsc > 0.5)
				{
					if (onKeyboardMode)
						ClientPrefs.keyBinds.get(curOption[2])[altNum] = NONE;
					else
						ClientPrefs.gamepadBinds.get(curOption[2])[altNum] = NONE;
					if (curSelected >= 2) ClientPrefs.clearInvalidKeys(curOption[2]);
					updateBind(Math.floor(curSelected * 2) + altNum, onKeyboardMode ? InputFormatter.getKeyName(NONE) : InputFormatter.getGamepadName(NONE));
					FlxG.sound.play(Paths.sound('cancelMenu'));
					closeBinding();
				}
			}
			else
			{
				holdingEsc = 0;
				var changed:Bool = false;
				var curKeys:Array<FlxKey> = ClientPrefs.keyBinds.get(curOption[2]);
				var curButtons:Array<FlxGamepadInputID> = ClientPrefs.gamepadBinds.get(curOption[2]);

				if(onKeyboardMode)
				{
					if(FlxG.keys.justPressed.ANY || FlxG.keys.justReleased.ANY)
					{
						var keyPressed:Int = FlxG.keys.firstJustPressed();
						var keyReleased:Int = FlxG.keys.firstJustReleased();
						if (keyPressed > -1 && keyPressed != FlxKey.ESCAPE && keyPressed != FlxKey.BACKSPACE)
						{
							curKeys[altNum] = keyPressed;
							changed = true;
						}
						else if (keyReleased > -1 && (keyReleased == FlxKey.ESCAPE || keyReleased == FlxKey.BACKSPACE))
						{
							curKeys[altNum] = keyReleased;
							changed = true;
						}
					}
				}
				else if(FlxG.gamepads.anyJustPressed(ANY) || FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER) || FlxG.gamepads.anyJustReleased(ANY))
				{
					var keyPressed:Null<FlxGamepadInputID> = NONE;
					var keyReleased:Null<FlxGamepadInputID> = NONE;
					if(FlxG.gamepads.anyJustPressed(LEFT_TRIGGER)) keyPressed = LEFT_TRIGGER; //it wasnt working for some reason
					else if(FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER)) keyPressed = RIGHT_TRIGGER; //it wasnt working for some reason
					else
					{
						for (i in 0...FlxG.gamepads.numActiveGamepads)
						{
							var gamepad:FlxGamepad = FlxG.gamepads.getByID(i);
							if(gamepad != null)
							{
								keyPressed = gamepad.firstJustPressedID();
								keyReleased = gamepad.firstJustReleasedID();

								if(keyPressed == null) keyPressed = NONE;
								if(keyReleased == null) keyReleased = NONE;
								if(keyPressed != NONE || keyReleased != NONE) break;
							}
						}
					}

					if (keyPressed != NONE && keyPressed != FlxGamepadInputID.BACK && keyPressed != FlxGamepadInputID.B)
					{
						curButtons[altNum] = keyPressed;
						changed = true;
					}
					else if (keyReleased != NONE && (keyReleased == FlxGamepadInputID.BACK || keyReleased == FlxGamepadInputID.B))
					{
						curButtons[altNum] = keyReleased;
						changed = true;
					}
				}

				if(changed)
				{
					if (onKeyboardMode)
					{
						if(curKeys[altNum] == curKeys[1 - altNum])
							curKeys[1 - altNum] = FlxKey.NONE;
					}
					else
					{
						if(curButtons[altNum] == curButtons[1 - altNum])
							curButtons[1 - altNum] = FlxGamepadInputID.NONE;
					}

					var option:String = currentOption()[2];
					if (curSelected >= 2) ClientPrefs.clearInvalidKeys(option);
					for (n in 0...2)
					{
						var key:String = null;
						if(onKeyboardMode)
						{
							var savKey:Array<Null<FlxKey>> = ClientPrefs.keyBinds.get(option);
							key = InputFormatter.getKeyName(savKey[n] != null ? savKey[n] : NONE);
						}
						else
						{
							var savKey:Array<Null<FlxGamepadInputID>> = ClientPrefs.gamepadBinds.get(option);
							key = InputFormatter.getGamepadName(savKey[n] != null ? savKey[n] : NONE);
						}
						updateBind(Math.floor(curSelected * 2) + n, key);
					}
					FlxG.sound.play(Paths.sound('confirmMenu'));
					closeBinding();
				}
			}
		}
		super.update(elapsed);
		positionNotes();
	}

	function closeBinding()
	{
		binding = false;
		bindingBlack.destroy();
		remove(bindingBlack);

		bindingText.destroy();
		remove(bindingText);

		bindingText2.destroy();
		remove(bindingText2);
		ClientPrefs.reloadVolumeKeys();
		timeForMoving = 0.1;
		updateAlt();
	}

	function updateText(?change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, curOptions.length - 1);

		var num:Int = curOptionsValid[curSelected];
		var addNum:Int = 0;
		if(curSelected < 2 || num < 3) addNum = 3 - num;
		else if(num > lastID - 4) addNum = (lastID - 4) - num;

		grpDisplay.forEachAlive(function(item:Alphabet) {
			item.targetY = item.ID - num - addNum;
		});

		grpOptions.forEachAlive(function(item:Alphabet)
		{
			item.targetY = item.ID - num - addNum;
			item.alpha = (item.ID - num == 0) ? 1 : 0.6;
		});
		grpBinds.forEachAlive(function(item:Alphabet)
		{
			var parent:Alphabet = grpOptions.members[item.ID];
			item.targetY = parent.targetY;
			item.alpha = parent.alpha;
		});

		updateAlt();
		positionNotes();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function positionNotes():Void
	{
		noteBindings.y = grpOptions.members[0].y - 194;
		// AttachedSprite normally updates before the bind text does.
		if (curSelected < 2) selectSpr.update(0);
	}
	function changeKeys(change:Int):Void
	{
		if (curSelected >= 2) return;
		noteBindings.keys = FlxMath.wrap(noteBindings.keys + change, 1, KeyMode.layouts.length);
		noteBindings.rebuild(); updateAlt();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
	function moveHorizontal(change:Int):Void
	{
		if (curSelected >= 2) { updateAlt(true); return; }
		noteBindings.lane = FlxMath.wrap(noteBindings.lane + change, 0, noteBindings.keys - 1);
		updateAlt(); FlxG.sound.play(Paths.sound('scrollMenu'));
	}
	function currentOption():Array<Dynamic>
	{
		if (curSelected >= 2) return options[curOptions[curSelected]];
		var action = KeyMode.action(noteBindings.keys, noteBindings.lane);
		var keys = ClientPrefs.keyBinds.get(action);
		var buttons = ClientPrefs.gamepadBinds.get(action);
		while (keys.length < 2) keys.push(NONE);
		while (buttons.length < 2) buttons.push(NONE);
		return [true, 'Notes', action, '${noteBindings.keys}K Note ${noteBindings.lane + 1}'];
	}

	function swapMode()
	{
		FlxTween.cancelTweensOf(bg);
		FlxTween.color(bg, 0.5, bg.color, onKeyboardMode ? gamepadColor : keyboardColor, {ease: FlxEase.linear});
		onKeyboardMode = !onKeyboardMode;

		curSelected = 0;
		curAlt = false;
		controllerSpr.animation.play(onKeyboardMode ? 'keyboard' : 'gamepad');
		createTexts();
	}

	function updateAlt(?doSwap:Bool = false)
	{
		if(doSwap)
		{
			curAlt = !curAlt;
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		noteBindings.select(curSelected < 2 ? curSelected : -1);
		if (curSelected < 2) {
			selectSpr.sprTracker = noteBindings.cells[curSelected * noteBindings.keys + noteBindings.lane];
			selectSpr.scale.set(selectSpr.sprTracker.width / 250, 1);
		} else {
			selectSpr.scale.set(1, 1);
			selectSpr.sprTracker = grpBlacks.members[Math.floor(curSelected * 2) + (curAlt ? 1 : 0)];
		}
		selectSpr.updateHitbox();
		selectSpr.visible = (selectSpr.sprTracker != null);
	}
}
