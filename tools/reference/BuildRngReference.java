import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.security.MessageDigest;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.CharacterTag;
import com.jpexs.decompiler.flash.action.parser.script.ActionScript2Parser;
import com.jpexs.decompiler.flash.action.swf4.*;
import com.jpexs.decompiler.flash.action.swf5.*;

/** Execute original generation/population timelines; adapt only random opcode boundaries. */
class BuildRngReference {
    static String hash(byte[] bytes) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
    }
    static DoActionTag script(SWF swf, String text) throws Exception {
        var tag = new DoActionTag(swf);
        tag.setActions(new ActionScript2Parser(swf, tag).actionsFromString(text, "UTF-8"));
        return tag;
    }
    public static void main(String[] args) throws Exception {
        var swf = new SWF(new FileInputStream(args[0]), false);
        boolean raw = args.length > 3 && args[3].equals("--raw-control");
        var game = (DefineSpriteTag) swf.getCharacters(false).get(564);
        var tags = new ArrayList<Tag>();
        var audit = new ArrayList<String>();
        int frame = 1;
        int count = 0;
        for (var tag : game.getTags()) {
            if (tag instanceof DoActionTag action && frame <= 2) {
                String before = hash(action.getActionBytes().getRangeData());
                var actions = action.getActions();
                var addresses = new ArrayList<Long>();
                for (int i=actions.size()-1; i>=0 && !raw; i--) {
                    if (!(actions.get(i) instanceof ActionRandomNumber)) continue;
                    long address = actions.get(i).getAddress();
                    addresses.add(address);
                    actions.addActions(i, List.of(
                        new ActionPush(new Object[]{"f"+frame+":"+address}, "UTF-8"),
                        new ActionStackSwap(),
                        new ActionPush(new Object[]{2L,"fixtureRandom"}, "UTF-8"),
                        new ActionCallFunction()));
                    actions.removeAction(i+4);
                    count++;
                }
                if(!raw) {action.setActions(actions);action.setModified(true);}
                audit.add("{\"frame\":"+frame+",\"original_sha256\":\""+before+"\",\"adapted_sha256\":\""+
                          hash(action.getActionBytes().getRangeData())+"\",\"random_addresses\":"+addresses+"}");
                if(frame==1) tags.add(script(swf,"function fixtureRandom(bound,site){return _root.fixtureRandom(bound,site);}"));
                tags.add(tag);
                tags.add(script(swf,frame==1 ? "_root.snapshot(\"topology\");" : "delete this.onEnterFrame;pausing=true;_root.roundReady();"));
            } else tags.add(tag);
            if(tag instanceof ShowFrameTag) frame++;
        }
        if(audit.size()!=2 || (!raw && count<20)) throw new IllegalStateException("Missing original generation blocks");
        var old = new ArrayList<Tag>();
        for(var tag:game.getTags()) old.add(tag);
        for(var tag:old) game.removeTag(tag);
        for(var tag:tags) game.addTag(tag);
        game.setModified(true);
        old.clear();
        for(var tag:swf.getTags()) {
            if(!(tag instanceof CharacterTag || tag instanceof ExportAssetsTag || tag instanceof FileAttributesTag ||
                 tag instanceof SetBackgroundColorTag || tag instanceof JPEGTablesTag || tag.getClass().getSimpleName().startsWith("DefineFont"))) old.add(tag);
        }
        for(var tag:old) swf.removeTag(tag);
        var export = new ExportAssetsTag(swf);
        export.tags=List.of(564);export.names=List.of("fixtureRngGame");swf.addTag(export);
        swf.addTag(script(swf,"var rawControl="+raw+";\n"+Files.readString(Path.of(args[2]))));
        swf.addTag(new ShowFrameTag(swf));swf.frameCount=1;swf.frameRate=35;
        try(var stream=new FileOutputStream(args[1])) {swf.saveTo(stream);}
        Files.writeString(Path.of(args[1]+".random.json"),"{\"sprite\":564,\"sites\":"+count+",\"frames\":["+String.join(",",audit)+"]}\n");
        System.out.println("RNG_REFERENCE_BUILT "+count+" original random sites; other original actions preserved");
        System.exit(0);
    }
}
