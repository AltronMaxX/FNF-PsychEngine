package backend;

#if DISCORD_ALLOWED
import sys.thread.Thread;
import sys.thread.Mutex;
import lime.app.Application;

import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;

class DiscordClient
{
	public static var isInitialized:Bool = false;
	private static var isConnected:Bool = false;
	private inline static final _defaultID:String = "1225820017468379247";
	public static var clientID(default, set):String = _defaultID;
	private static var presence:DiscordPresence;
	private static var presenceClock:DiscordPresenceClock = new DiscordPresenceClock();
	private static var lastSentPresence:String = null;
	private static var lastSentTime:Float = -15;
	private static var presenceMutex:Mutex = new Mutex();
	private static var prepared:Bool = false;
	private static var forcePresenceUpdate:Bool = false;
	// Poll independently of gameplay while respecting Discord's activity update limit.
	public static inline final UPDATE_INTERVAL:Float = 15;
	public static inline final REFRESH_INTERVAL:Float = 60;
	// hides this field from scripts and reflection in general
	@:unreflective private static var __thread:Thread;

	public static function check()
	{
		if(ClientPrefs.data.discordRPC)
		{
			if(!isInitialized) initialize();
		}
		else if(isInitialized) shutdown();
	}
	
	public static function prepare()
	{
		if(prepared) return;
		prepared = true;
		if (!isInitialized && ClientPrefs.data.discordRPC)
			initialize();

		Application.current.window.onClose.add(function() {
			if(isInitialized) shutdown();
		});
	}

	public dynamic static function shutdown()
	{
		withPresenceLock(function()
		{
			isInitialized = false;
			isConnected = false;
			Discord.Shutdown();
		});
	}
	
	private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
	{
		final user = cast (request[0].username, String);
		final discriminator = cast (request[0].discriminator, String);
		
		var message = '(Discord) Connected to User ';
		if (discriminator != '0') //Old discriminators
			message += '($user#$discriminator)';
		else //New Discord IDs/Discriminator system
			message += '($user)';

		trace(message);

		// Callbacks and sends run on the same worker, under presenceMutex.
		forcePresenceUpdate = true;
		isConnected = true;
	}

	private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Discord: Error ($errorCode: ${cast(message, String)})');
		// Retry the latest cache after the cooldown, without an immediate burst.
		forcePresenceUpdate = true;
	}

	private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Discord: Disconnected ($errorCode: ${cast(message, String)})');
		isConnected = false;
	}

	public static function initialize()
	{
		withPresenceLock(function()
		{
			isConnected = false;
			var discordHandlers:DiscordEventHandlers = DiscordEventHandlers.create();
			discordHandlers.ready = cpp.Function.fromStaticFunction(onReady);
			discordHandlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
			discordHandlers.errored = cpp.Function.fromStaticFunction(onError);
			Discord.Initialize(clientID, cpp.RawPointer.addressOf(discordHandlers), 1, null);

			if(!isInitialized) trace("Discord Client initialized");

			if (__thread == null)
			{
				__thread = Thread.create(() ->
				{
					while (true)
					{
						try
						{
							updateClient();
						}
						catch (error:Dynamic)
						{
							trace('Discord: Update failed ($error)');
							withPresenceLock(function() forcePresenceUpdate = true);
						}
						Sys.sleep(0.25);
					}
				});
			}
			isInitialized = true;
		});
	}

	public static function changePresence(details:String = 'Main Menu', ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool,
		?endTimestamp:Float, largeImageKey:String = 'icon', ?artist:String)
	{
		// Preserve the legacy argument slots; the elapsed timer now follows the game state.
		var nowMs = Date.now().getTime();
		var context = FlxG.game != null ? FlxG.state : null;
		endTimestamp = endTimestamp != null && endTimestamp > 0 ? nowMs + endTimestamp : 0;

		withPresenceLock(function()
		{
			// Only cache here. The worker reads a complete payload, never half of a new status.
			if(presence == null) presence = new DiscordPresence();
			presence.details = DiscordPresenceData.limitText(details);
			presence.state = DiscordPresenceData.limitText(state);
			presence.largeImageKey = DiscordPresenceData.assetKey(largeImageKey);
			presence.largeImageText = DiscordPresenceData.limitText(DiscordPresenceData.hover(states.MainMenuState.psychEngineVersion, artist));
			presence.startTimestamp = presenceClock.startTimestamp(context, Std.int(nowMs / 1000));
			presence.endTimestamp = Std.int(endTimestamp / 1000);
		});
	}

	private static function updateClient():Void
	{
		withPresenceLock(function()
		{
			if(!isInitialized) return;
			Discord.RunCallbacks();
			flushPresence();
			#if DISCORD_DISABLE_IO_THREAD
			Discord.UpdateConnection();
			#end
		});
	}

	private static function flushPresence():Void
	{
		if(!isInitialized || !isConnected || !ClientPrefs.data.discordRPC || presence == null) return;
		var now = haxe.Timer.stamp();
		// READY/errors must not bypass the same limit as ordinary menu changes.
		if(now - lastSentTime < UPDATE_INTERVAL) return;
		var signature = presence.toString();
		if(!forcePresenceUpdate && signature == lastSentPresence && now - lastSentTime < REFRESH_INTERVAL) return;
		// The worker keeps checking new requests. Unchanged snapshots need only a
		// sparse refresh, leaving Discord time to publish the previous submission.
		presence.prepareNative();
		presence.__presence.type = DiscordActivityType_Playing;
		var button = DiscordButton.create();
		button.label = 'Download the Mod';
		button.url = 'https://gamebanana.com/mods/681142';
		presence.__presence.buttons[0] = button;
		var emptyButton = DiscordButton.create();
		emptyButton.label = null;
		emptyButton.url = null;
		presence.__presence.buttons[1] = emptyButton;
		lastSentTime = now;
		Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence.__presence));
		lastSentPresence = signature;
		forcePresenceUpdate = false;
	}

	private static function withPresenceLock(action:Void->Void):Void
	{
		presenceMutex.acquire();
		try action()
		catch (error:Dynamic)
		{
			presenceMutex.release();
			throw error;
		}
		presenceMutex.release();
	}

	inline public static function resetClientID()
	{
		clientID = _defaultID;
	}

	private static function set_clientID(newID:String)
	{
		var change:Bool = (clientID != newID);
		clientID = newID;

		if(change && isInitialized)
		{
			shutdown();
			initialize();
		}
		return newID;
	}

	#if MODS_ALLOWED
	public static function loadModRPC()
	{
		var pack:Dynamic = Mods.getPack();
		if(pack != null && pack.discordRPC != null && pack.discordRPC != clientID)
		{
			clientID = pack.discordRPC;
			//trace('Changing clientID! $clientID, $_defaultID');
		}
	}
	#end

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State)
	{
		Lua_helper.add_callback(lua, "changeDiscordPresence", changePresence);
		Lua_helper.add_callback(lua, "changeDiscordClientID", function(?newID:String) {
			if(newID == null) newID = _defaultID;
			clientID = newID;
		});
	}
	#end
}

@:allow(backend.DiscordClient)
private final class DiscordPresence
{
	public var state:String;
	public var details:String;
	public var largeImageKey:String;
	public var largeImageText:String;
	public var startTimestamp:Int = 0;
	public var endTimestamp:Int = 0;

	@:noCompletion private var __presence:DiscordRichPresence;
	private var nativeText:Array<DiscordCString> = [];

	function new()
	{
		__presence = DiscordRichPresence.create();
	}

	private function prepareNative():Void
	{
		// String.utf8_str() can allocate a temporary buffer for non-ASCII text.
		// Keeping the original String alive does not keep that conversion alive.
		nativeText = [new DiscordCString(details), new DiscordCString(state),
			new DiscordCString(largeImageKey), new DiscordCString(largeImageText)];
		__presence = DiscordRichPresence.create();
		__presence.details = nativeText[0].pointer;
		__presence.state = nativeText[1].pointer;
		__presence.largeImageKey = nativeText[2].pointer;
		__presence.largeImageText = nativeText[3].pointer;
		__presence.smallImageKey = null;
		__presence.smallImageText = null;
		__presence.startTimestamp = startTimestamp;
		__presence.endTimestamp = endTimestamp;
	}

	public function toString():String
	{
		// Avoid Flixel's shared LabelValuePair pool on the Discord worker.
		return haxe.Json.stringify([state, details, largeImageKey,
			largeImageText, startTimestamp, endTimestamp]);
	}

}
#end

#if cpp
/** Owns a null-terminated UTF-8 buffer for the native Discord RPC call. */
class DiscordCString
{
	private var bytes:haxe.io.Bytes;
	public var pointer(get, never):cpp.ConstCharStar;

	public function new(value:String)
	{
		bytes = value != null ? haxe.io.Bytes.ofString(value + '\x00') : null;
	}

	private function get_pointer():cpp.ConstCharStar
	{
		if(bytes == null) return null;
		var chars:cpp.Pointer<cpp.Char> = cpp.Pointer.ofArray(bytes.getData()).reinterpret();
		return cast chars.constRaw;
	}
}
#end

/** Keeps the elapsed-time origin while the same game state updates its presence text. */
class DiscordPresenceClock
{
	private var context:Dynamic;
	private var initialized:Bool = false;
	private var startedAt:Int = 0;

	public function new() {}

	public function startTimestamp(currentContext:Dynamic, nowSeconds:Int):Int
	{
		if(!initialized || context != currentContext)
		{
			context = currentContext;
			startedAt = nowSeconds;
			initialized = true;
		}
		return startedAt;
	}
}

/** Text formatting shared by gameplay and Discord, without depending on the native RPC library. */
class DiscordPresenceData
{
	public static function songDetails(song:String, difficulty:String, status:String):String
	{
		var prefix = '$status - ';
		var suffix = ' [' + limitText(difficulty, 32) + ']';
		// Preserve the difficulty even when a song title is very long.
		var titleBytes = 127 - haxe.io.Bytes.ofString(prefix + suffix).length;
		return prefix + limitText(song, titleBytes) + suffix;
	}

	public static function remainingSongMs(lengthMs:Float, positionMs:Float, finished:Bool = false):Float
	{
		if(finished || !Math.isFinite(lengthMs)) return 0;
		if(!Math.isFinite(positionMs)) positionMs = 0;
		// Match Vindix UI: inst.length - getSongPosition(), including the countdown.
		return Math.max(0, lengthMs - positionMs);
	}

	public static function timeLeft(remainingMs:Float):String
	{
		if(!Math.isFinite(remainingMs)) remainingMs = 0;
		var seconds:Int = Math.floor(Math.max(0, remainingMs) / 1000);
		return Std.int(seconds / 60) + ':' + StringTools.lpad(Std.string(seconds % 60), '0', 2);
	}

	public static function formatScore(score:Int):String
	{
		// Group the digits as text to avoid overflowing on the smallest negative Int.
		var digits = Std.string(score);
		var start = score < 0 ? 1 : 0;
		var result = digits.substr(0, start);
		for(i in start...digits.length)
		{
			if(i > start && (digits.length - i) % 3 == 0) result += ',';
			result += digits.charAt(i);
		}
		return result;
	}

	public static function statistics(score:Int, remainingMs:Float, botplay:Bool = false):String
	{
		return (botplay ? 'BOTPLAY' : 'Score: ${formatScore(score)}') + ' · Time Left: ' + timeLeft(remainingMs);
	}

	public static function hover(version:String, ?artist:String):String
	{
		if(artist != null) artist = StringTools.trim(artist);
		return 'Mod Version: ' + version + (artist != null && artist.length > 0 ? ' · Artist: ' + artist : '');
	}

	public static function assetKey(value:String):String
	{
		if(value == null || StringTools.trim(value).length == 0) return null;
		value = StringTools.trim(value);
		return StringTools.startsWith(value, 'https://') || StringTools.startsWith(value, 'http://') ? value : value.toLowerCase();
	}

	/** Discord's text limit is measured in UTF-8 bytes, not characters. */
	public static function limitText(value:String, maxBytes:Int = 127):String
	{
		if(value == null) return null;
		if(maxBytes <= 0) return '';
		var bytes = haxe.io.Bytes.ofString(value);
		if(bytes.length <= maxBytes) return value;
		var end = maxBytes;
		while(end > 0 && (bytes.get(end) & 0xC0) == 0x80) end--;
		return bytes.getString(0, end);
	}
}
