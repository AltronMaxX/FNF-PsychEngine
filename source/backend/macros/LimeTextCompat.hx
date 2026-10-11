package backend.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

/** Compatibility for the engine's pinned OpenFL/Lime native text renderer. */
class LimeTextCompat
{
    public static function install():Void
    {
        if (Context.definedValue('openfl') == '9.3.3' && Context.definedValue('lime') == '8.2.3'
            && Context.defined('lime_cffi') && !Context.defined('flash'))
            haxe.macro.Compiler.addGlobalMetadata('openfl.text._internal.TextLayout',
                '@:build(backend.macros.LimeTextCompat.build())', false, true, false);
    }

    public static function build():Array<Field>
    {
        var fields = Context.getBuildFields();
        for (field in fields)
        {
            if (field.name != 'set_size') continue;
            switch (field.kind)
            {
                case FFun(fn):
                    var original = fn.expr;
                    // Lime 8.2.3's HarfBuzz font retains metrics at its creation size.
                    // OpenFL 9.3.3 updates only FreeType when the size changes.
                    // Invalidate the cached font so __position rebuilds it at the new size.
                    fn.expr = macro {
                        if (value != this.size) __font = null;
                        $original;
                    };
                    return fields;
                default:
            }
        }
        Context.error('OpenFL TextLayout.set_size changed; review LimeTextCompat.', Context.currentPos());
        return fields;
    }
}
#end
