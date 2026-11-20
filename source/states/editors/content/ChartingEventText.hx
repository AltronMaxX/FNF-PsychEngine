package states.editors.content;

/** Fit labels using the actual font metrics, without changing chart values. */
class ChartingEventText
{
	public static function singleLine(value:String):String
		return value == null ? '' : value.split('\r').join(' ').split('\n').join(' ');

	static function prefixLength(value:UnicodeString, width:Float, measure:String->Float):Int
	{
		var low = 0;
		var high = value.length;
		while(low < high)
		{
			var mid = Std.int((low + high + 1) / 2);
			if(measure(value.substr(0, mid)) <= width) low = mid;
			else high = mid - 1;
		}
		return low;
	}

	public static function ellipsize(value:String, width:Float, measure:String->Float):String
	{
		var line:UnicodeString = singleLine(value);
		if(measure(line) <= width) return line;
		var dots = '...';
		while(dots.length > 0 && measure(dots) > width) dots = dots.substr(1);
		return line.substr(0, prefixLength(line, Math.max(0, width - measure(dots)), measure)).rtrim() + dots;
	}

	public static function compact(events:Array<Array<String>>, width:Float, measure:String->Float):String
	{
		if(events.length == 1)
		{
			var e = events[0];
			return [for (line in ['Event: ' + singleLine(e[0]), 'Value 1: ' + singleLine(e[1]), 'Value 2: ' + singleLine(e[2])])
				ellipsize(line, width, measure)].join('\n');
		}
		var names:UnicodeString = [for (e in events) singleLine(e[0])].join(', ');
		var end = prefixLength(names, width, measure);
		if(end < names.length)
		{
			var space = names.lastIndexOf(' ', end);
			if(space > 0) end = space;
		}
		return events.length + ' Events:\n' + names.substr(0, end).rtrim() + '\n'
			+ ellipsize(names.substr(end).ltrim(), width, measure);
	}
}
