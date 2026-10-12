import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.security.MessageDigest;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.action.swf4.*;
import com.jpexs.decompiler.flash.action.swf5.ActionCallFunction;

/** Adapt only RandomNumber call sites; original AI control flow stays executable. */
class ForceAiDecisions {
    public static void main(String[] args) throws Exception {
        var swf = new SWF(new FileInputStream(args[0]), false);
        var game = (DefineSpriteTag) swf.getCharacters(false).get(564);
        String original = "b68c1872f3a1a9967dee94c3bae9d50ca9c52aab0caa357ea5d78de993e62a9b";
        int changed = 0;
        String controlled = "";
        var addresses = new ArrayList<Long>();
        for (var tag : game.getTags()) {
            if (!(tag instanceof DoActionTag action)) continue;
            String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(action.getActionBytes().getRangeData()));
            if (!hash.equals(original)) continue;
            var actions = action.getActions();
            for (int i = actions.size()-1; i >= 0; i--) {
                if (!(actions.get(i) instanceof ActionRandomNumber)) continue;
                addresses.add(actions.get(i).getAddress());
                actions.addActions(i, List.of(new ActionPush(new Object[]{1L,"fixtureRandom"},"UTF-8"),new ActionCallFunction()));
                actions.removeAction(i+2);
                changed++;
            }
            if (actions.stream().anyMatch(a -> a instanceof ActionRandomNumber)) throw new IllegalStateException("Unadapted random call");
            action.setActions(actions);
            action.setModified(true);
            game.setModified(true);
            controlled = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(action.getActionBytes().getRangeData()));
        }
        if (changed != 11) throw new IllegalStateException("Original polling block not found");
        try (var output = new FileOutputStream(args[0])) { swf.saveTo(output); }
        Files.writeString(Path.of(args[0]+".random.json"), "{\"original_polling_sha256\":\""+original+"\",\"controlled_polling_sha256\":\""+controlled+"\",\"random_number_sites\":"+changed+",\"original_addresses\":"+addresses+"}\n");
        System.out.println("Adapted only RandomNumber boundaries: "+changed);
        System.exit(0);
    }
}
