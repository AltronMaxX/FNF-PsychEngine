package options;

import backend.ClientPrefs.VisualOptions;

class AudioSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		VisualOptions.reload(true);
		title = Language.getPhrase('audio_menu', 'Audio Settings');
		rpcTitle = 'Audio Settings Menu';

		var option:Option = new Option('Hitsound Volume',
			'Volume of the sound played when the player hits a note.',
			'hitsoundVolume',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = onChangeHitsoundVolume;
		addOption(option);

		var option:Option = new Option('Note Miss Volume',
			'Volume of the sound played when you miss a note.',
			'noteMissVolume',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = onChangeMissVolume.bind(false);
		addOption(option);

		var option:Option = new Option('Ghost Miss Volume',
			'Volume of the sound played when you press a key without a note.\nOnly applies when Ghost Tapping is disabled.',
			'ghostMissVolume',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = onChangeMissVolume.bind(true);
		addOption(option);

		var option:Option = new Option('Mute Vocals on Miss',
			'If checked, misses mute the player vocals until the next successful hit.',
			'muteVocalsOnMiss',
			BOOL);
		addOption(option);

		var option:Option = new Option('Pause Music:',
			'What song do you prefer for the Pause Screen?',
			'pauseMusic',
			STRING,
			VisualOptions.getValues('pauseMusic'));
		option.onChange = onChangePauseMusic;
		addOption(option);

		super();
	}

	function onChangeHitsoundVolume()
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);

	function onChangeMissVolume(ghost:Bool)
	{
		if (OptionsSubState.fromPause && PlayState.instance != null)
		{
			PlayState.instance.playMissSound(ghost);
			return;
		}
		var volume:Float = ghost ? ClientPrefs.data.ghostMissVolume : ClientPrefs.data.noteMissVolume;
		if (volume <= 0) return;
		var count:Int = 0;
		while (Paths.fileExists(Language.getFileTranslation('sounds/missnote${count + 1}') + '.${Paths.SOUND_EXT}', SOUND))
			count++;
		if (count > 0)
			FlxG.sound.play(Paths.soundRandom('missnote', 1, count), FlxG.random.float(0.1, 0.2) * volume);
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if (OptionsSubState.fromPause)
		{
			OptionsSubState.instance.previewPauseMusic();
			return;
		}
		if (ClientPrefs.data.pauseMusic == 'None')
			FlxG.sound.music.volume = 0;
		else
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)));
		changedMusic = true;
	}

	override function destroy()
	{
		if (changedMusic && !OptionsSubState.fromPause) FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
		super.destroy();
	}
}
