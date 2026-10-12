import java.io.*;
import java.util.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.ShapeTag;

/** Remove only unrelated drawing definitions. Timelines, matrices, colors,
 * frame scripts and original gameplay function bytecode remain unchanged. */
class IsolateDeath {
    public static void main(String[] args) throws Exception {
        var swf = new SWF(new FileInputStream(args[0]), false);
        String part = args[2].replace("-black", "");
        var kept = new ArrayList<Integer>();
        for (var tag : new ArrayList<>(swf.getCharacters(false).values())) {
            if (!(tag instanceof ShapeTag shape)) continue;
            int id = shape.getCharacterId();
            boolean keep = switch (part) {
                case "body" -> id > 2 && id < 90;
                case "burst" -> Set.of(239,241,243,245,247).contains(id);
                case "silhouette" -> id == 233 || id == 235;
                case "eyes" -> id == 234;
                case "shadow" -> id == 2 || id == 232;
                case "smoke" -> id == 278;
                default -> throw new IllegalArgumentException("Unknown component " + part);
            };
            if (keep) { kept.add(id); continue; }
            var empty = new DefineSpriteTag(swf);
            empty.spriteId = id;
            empty.frameCount = 1;
            empty.addTag(new ShowFrameTag(swf));
            swf.replaceTag(tag, empty);
        }
        try (var stream = new FileOutputStream(args[1])) { swf.saveTo(stream); }
        System.out.println("Kept original drawing definitions for " + part + ": " + kept);
        System.exit(0);
    }
}
