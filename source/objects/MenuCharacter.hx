package objects;

import openfl.utils.Assets;
import haxe.Json;

typedef MenuCharacterFile = {
	var image:String;
	var scale:Float;
	var position:Array<Int>;
	var idle_anim:String;
	// Frame numbers from idle_anim, in playback order, for alternating beat dances.
	@:optional var dance_left:Array<Int>;
	@:optional var dance_right:Array<Int>;
	var confirm_anim:String;
	var flipX:Bool;
	var antialiasing:Null<Bool>;
}

class MenuCharacter extends FlxSprite
{
	public var character:String;
	public var hasConfirmAnimation:Bool = false;
	public var danceIdle(default, null):Bool = false;
	public var danceEveryNumBeats(default, null):Int = 2;
	var danced:Bool = false;
	private static var DEFAULT_CHARACTER:String = 'bf';

	public function new(x:Float, character:String = 'bf')
	{
		super(x);

		changeCharacter(character);
	}

	public function changeCharacter(?character:String = 'bf') {
		if(character == null) character = '';
		if(character == this.character) return;

		this.character = character;
		visible = true;

		scale.set(1, 1);
		updateHitbox();
		
		color = FlxColor.WHITE;
		alpha = 1;

		hasConfirmAnimation = false;
		switch(character) {
			case '':
				visible = false;
			default:
				var characterPath:String = 'images/menucharacters/' + character + '.json';

				var path:String = Paths.getPath(characterPath, TEXT);
				#if MODS_ALLOWED
				if (!FileSystem.exists(path))
				#else
				if (!Assets.exists(path))
				#end
				{
					path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
					color = FlxColor.BLACK;
					alpha = 0.6;
				}

				var charFile:MenuCharacterFile = null;
				try
				{
					#if MODS_ALLOWED
					charFile = Json.parse(File.getContent(path));
					#else
					charFile = Json.parse(Assets.getText(path));
					#end
				}
				catch(e:Dynamic)
				{
					trace('Error loading menu character file of "$character": $e');
				}

				loadCharacterFile(charFile);
		}
	}

	public function loadCharacterFile(charFile:MenuCharacterFile)
	{
		// A new definition may reuse the same atlas; clear the previous dance/confirm animations too.
		animation.destroyAnimations();
		frames = Paths.getSparrowAtlas('menucharacters/' + charFile.image);
		animation.addByPrefix('idle', charFile.idle_anim, 24, false);
		danced = false;
		danceIdle = false;
		hasConfirmAnimation = false;

		if(charFile.dance_left != null && charFile.dance_left.length > 0
			&& charFile.dance_right != null && charFile.dance_right.length > 0)
		{
			animation.addByIndices('danceLeft', charFile.idle_anim, charFile.dance_left, '', 24, false);
			animation.addByIndices('danceRight', charFile.idle_anim, charFile.dance_right, '', 24, false);
			danceIdle = animation.getByName('danceLeft') != null && animation.getByName('danceRight') != null;
		}
		danceEveryNumBeats = danceIdle ? 1 : 2;

		var confirmAnim:String = charFile.confirm_anim;
		if(confirmAnim != null && confirmAnim.length > 0 && confirmAnim != charFile.idle_anim)
		{
			animation.addByPrefix('confirm', confirmAnim, 24, false);
			hasConfirmAnimation = animation.getByName('confirm') != null;
		}

		flipX = (charFile.flipX == true);
		scale.set(charFile.scale, charFile.scale);
		updateHitbox();
		offset.set(charFile.position[0], charFile.position[1]);
		antialiasing = (charFile.antialiasing != false && ClientPrefs.data.antialiasing);
		dance();
	}

	public function dance()
	{
		if(danceIdle)
		{
			danced = !danced;
			animation.play(danced ? 'danceRight' : 'danceLeft', true);
		}
		else animation.play('idle', true);
	}

	public function beatHit(beat:Int)
	{
		if(!visible || beat % danceEveryNumBeats != 0 || animation.curAnim == null) return;
		switch(animation.curAnim.name)
		{
			case 'idle', 'danceLeft', 'danceRight': dance();
			default: // Do not interrupt confirmation or other special animations.
		}
	}
}
