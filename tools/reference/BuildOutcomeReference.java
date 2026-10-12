import java.io.*;
import java.nio.file.*;
import java.util.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.CharacterTag;
import com.jpexs.decompiler.flash.action.parser.script.ActionScript2Parser;
import com.jpexs.decompiler.flash.action.swf5.ActionDefineFunction;
import com.jpexs.decompiler.flash.action.swf5.ActionConstantPool;
import com.jpexs.decompiler.flash.action.swf7.ActionDefineFunction2;

/** Preserve original definitions and function bytecode; replace only scene setup. */
class BuildOutcomeReference {
    public static void main(String[] args) throws Exception {
        var swf = new SWF(new FileInputStream(args[0]), false);
        var game = (DefineSpriteTag) swf.getCharacters(false).get(564);
        DoActionTag original = null;
        for (var tag : game.getTags()) {
            if (tag instanceof DoActionTag action) { original = action; break; }
        }
        if (original == null) throw new IllegalStateException("Missing Sprite 564 actions");
        long end = 0;
        var functions = new ArrayList<String>();
        for (var action : original.getActions()) {
            if (action.getAddress() < end) continue;
            if (action instanceof ActionDefineFunction function) {
                functions.add(function.functionName);
                end = action.getAddress() + function.getHeaderSize() + function.codeSize;
            } else if (action instanceof ActionDefineFunction2 function) {
                functions.add(function.functionName);
                end = action.getAddress() + function.getHeaderSize() + function.codeSize;
            } else if (action instanceof ActionConstantPool) {
                end = action.getAddress() + action.getTotalActionLength();
            } else break;
        }
        if (!functions.containsAll(List.of("hurtHero", "bombExp", "brickBreak")))
            throw new IllegalStateException("Unexpected function layout: " + functions);
        var originalFunctions = new DoActionTag(swf);
        originalFunctions.setActionBytes(Arrays.copyOf(original.getActionBytes().getRangeData(), (int) end));
        var script = new DoActionTag(swf);
        script.setActions(new ActionScript2Parser(swf, script).actionsFromString(Files.readString(Path.of(args[2])), "UTF-8"));
        var remove = new ArrayList<Tag>();
        for (var tag : swf.getTags()) {
            if (!(tag instanceof CharacterTag || tag instanceof ExportAssetsTag ||
                  tag instanceof FileAttributesTag || tag instanceof SetBackgroundColorTag ||
                  tag instanceof JPEGTablesTag || tag.getClass().getSimpleName().startsWith("DefineFont"))) remove.add(tag);
        }
        for (var tag : remove) swf.removeTag(tag);
        // Execute the untouched functions in their original sprite scope.
        var gameTags = new ArrayList<Tag>();
        for(var tag:game.getTags()) gameTags.add(tag);
        for(var tag:gameTags) game.removeTag(tag);
        game.addTag(originalFunctions);
        var setupGame = new DoActionTag(swf);
        setupGame.setActions(new ActionScript2Parser(swf, setupGame).actionsFromString(Files.readString(Path.of(args[3])), "UTF-8"));
        game.addTag(setupGame); game.addTag(new ShowFrameTag(swf));game.frameCount=1;
        var exports = new ExportAssetsTag(swf);
        exports.tags = List.of(564,563,603,629);
        exports.names = List.of("fixtureGame","fixtureBanner","fixtureScores","fixtureFinal");
        swf.addTag(exports);
        swf.addTag(script);
        swf.addTag(new ShowFrameTag(swf));
        swf.frameCount = 1;
        swf.frameRate = 35;
        try (var stream = new FileOutputStream(args[1])) { swf.saveTo(stream); }
        System.out.println("Preserved " + functions.size() + " original function bodies (" + end + " bytes), and all character definitions.");
        System.exit(0);
    }
}
