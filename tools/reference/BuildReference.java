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
        if (args.length == 4) {
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
        swf.addTag(new ShowFrameTag(swf));
        swf.frameCount = 1;
        swf.frameRate = 35;
        try (var stream = new FileOutputStream(args[1])) { swf.saveTo(stream); }
        System.out.println("Preserved " + functions.size() + " original function bodies (" + end + " bytes), and all character definitions.");
        System.exit(0);
    }
}
