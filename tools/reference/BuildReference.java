import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.security.MessageDigest;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.CharacterTag;
import com.jpexs.decompiler.flash.action.parser.script.ActionScript2Parser;
import com.jpexs.decompiler.flash.action.swf5.ActionDefineFunction;
import com.jpexs.decompiler.flash.action.swf5.ActionConstantPool;
import com.jpexs.decompiler.flash.action.swf7.ActionDefineFunction2;

/** Preserve original definitions and function bytecode; replace only scene setup. */
class BuildReference {
    public static void main(String[] args) throws Exception {
        var swf = new SWF(new FileInputStream(args[0]), false);
        var game = (DefineSpriteTag) swf.getCharacters(false).get(564);
        DoActionTag original = null;
        DoActionTag frameTwo = null;
        int frame = 1;
        for (var tag : game.getTags()) {
            if (tag instanceof DoActionTag action && frame == 1) original = action;
            if (tag instanceof DoActionTag action && frame == 2) frameTwo = action;
            if (tag instanceof ShowFrameTag) frame++;
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
        swf.addTag(originalFunctions);
        boolean nestedOnly = args.length == 4 && args[3].equals("--nested-only");
        if (args.length >= 4 && !nestedOnly) {
            if (frameTwo == null) throw new IllegalStateException("Missing Sprite 564 frame 2 actions");
            var prelude = new DoActionTag(swf);
            prelude.setActions(new ActionScript2Parser(swf, prelude).actionsFromString(Files.readString(Path.of(args[3])), "UTF-8"));
            swf.addTag(prelude);
            var polling = new DoActionTag(swf);
            byte[] sourceBytes = frameTwo.getActionBytes().getRangeData();
            polling.setActionBytes(sourceBytes.clone());
            swf.addTag(polling);
            String sourceHash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(sourceBytes));
            String copyHash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(polling.getActionBytes().getRangeData()));
            if (!sourceHash.equals(copyHash)) throw new IllegalStateException("Frame 2 bytecode changed");
            Files.writeString(Path.of(args[1] + ".bytecode.json"), "{\"sprite\":564,\"frame\":2,\"bytes\":" + sourceBytes.length
                + ",\"original_sha256\":\"" + sourceHash + "\",\"preserved_sha256\":\"" + copyHash + "\"}\n");
            System.out.println("Preserved complete original frame 2 polling/release bytecode: " + sourceBytes.length + " bytes, SHA-256 " + sourceHash);
        }
        swf.addTag(script);
        if (nestedOnly || (args.length == 5 && args[4].equals("--nested"))) {
            // Retain real _parent writes for life, score and bomb-refund observations.
            var actions = new ArrayList<Tag>();
            for (var tag : swf.getTags()) if (tag instanceof DoActionTag) actions.add(tag);
            var oldGameTags = new ArrayList<Tag>();
            for (var tag : game.getTags()) oldGameTags.add(tag);
            for (var tag : oldGameTags) game.removeTag(tag);
            for (var tag : actions) { swf.removeTag(tag); game.addTag(tag); }
            game.addTag(new ShowFrameTag(swf));
            game.frameCount = 1;
            var exports = new ExportAssetsTag(swf);
            exports.tags = List.of(564);
            exports.names = List.of("fixtureGame");
            swf.addTag(exports);
            var rootSetup = new DoActionTag(swf);
            rootSetup.setActions(new ActionScript2Parser(swf, rootSetup).actionsFromString(
                "stop(); attachMovie(\"fixtureGame\", \"game\", 1);", "UTF-8"));
            swf.addTag(rootSetup);
            System.out.println("Preserved original Sprite 564 scope with real root parent ledger");
        }
        swf.addTag(new ShowFrameTag(swf));
        swf.frameCount = 1;
        swf.frameRate = 35;
        try (var stream = new FileOutputStream(args[1])) { swf.saveTo(stream); }
        var reloaded = new SWF(new FileInputStream(args[1]), false);
        Iterable<Tag> checkTags = (nestedOnly || (args.length == 5 && args[4].equals("--nested")))
            ? ((DefineSpriteTag) reloaded.getCharacters(false).get(564)).getTags() : reloaded.getTags();
        byte[] copied = null;
        for (var tag : checkTags) if (tag instanceof DoActionTag action) { copied = action.getActionBytes().getRangeData(); break; }
        byte[] prefix = Arrays.copyOf(original.getActionBytes().getRangeData(), (int) end);
        if (copied == null || !Arrays.equals(prefix, copied)) throw new IllegalStateException("Function bytecode changed after save");
        String functionHash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(prefix));
        Files.writeString(Path.of(args[1]+".functions.json"), "{\"sprite\":564,\"frame\":1,\"prefix_bytes\":"+end
            +",\"original_sha256\":\""+functionHash+"\",\"reloaded_sha256\":\""+functionHash+"\"}\n");
        System.out.println("Preserved " + functions.size() + " original function bodies (" + end + " bytes), and all character definitions.");
        System.exit(0);
    }
}
