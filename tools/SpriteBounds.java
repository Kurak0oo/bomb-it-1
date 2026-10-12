import java.io.*;
import java.nio.file.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.DefineSpriteTag;

// FFDec 26.3: register exported PNGs at the original SWF coordinates (twips/20).
class SpriteBounds {
    public static void main(String[] args) throws Exception {
        var swf = new SWF(new FileInputStream(args[0]), false);
        var rows = new java.util.ArrayList<String>();
        for (var tag : swf.getCharacters(false).values()) {
            if (tag instanceof DefineSpriteTag sprite) {
                var r = sprite.getRect();
                rows.add("\"" + sprite.spriteId + "\":[" + r.Xmin / 20.0 + "," + r.Ymin / 20.0 + "]");
            }
        }
        Files.writeString(Path.of(args[1]), "{" + String.join(",", rows) + "}");
    }
}
