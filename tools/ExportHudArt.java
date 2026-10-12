import java.io.*;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
import javax.imageio.ImageIO;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.timeline.*;
import com.jpexs.decompiler.flash.types.*;
import com.jpexs.decompiler.flash.exporters.commonshape.Matrix;

/** Source-only HUD extraction. Does not execute or change game bytecode. */
class ExportHudArt {
    static Path output;
    static void render(Timeline timeline, int frame, RECT bounds, String name) throws Exception {
        var image = SWF.frameToImageGet(timeline, frame, 0, null, 0, bounds,
            new Matrix(), new ColorTransform(), null, 2, true, 1);
        ImageIO.write(image.getBufferedImage(), "png", output.resolve(name).toFile());
    }
    public static void main(String[] args) throws Exception {
        if(args.length != 2) throw new IllegalArgumentException("Usage: ExportHudArt <source.swf> <output>");
        output = Path.of(args[1]); Files.createDirectories(output);
        var swf = new SWF(new FileInputStream(args[0]), false);
        var root = swf.getTimeline(); var frame = root.getFrame(8);
        var original = new TreeMap<>(frame.layers);
        frame.layers = new TreeMap<>(original);
        frame.layers.entrySet().removeIf(e -> Set.of(603,564,537,554,550,544,541,540,539).contains(e.getValue().characterId)
            || e.getValue().getCharacter() instanceof DefineEditTextTag);
        // Timer's TIME lettering remains; dynamic digits are rendered by the game.
        var timer = ((DefineSpriteTag)swf.getCharacter(527)).getTimeline();
        timer.getFrame(0).layers.entrySet().removeIf(e -> e.getValue().getCharacter() instanceof DefineEditTextTag);
        render(root,8,swf.displayRect,"background.png"); frame.layers = original;
        var pan = ((DefineSpriteTag)swf.getCharacter(536)).getTimeline();
        var bounds = new RECT(-800,800,-800,800);
        for(int index=0;index<4;index++) {
            var pf = pan.getFrame(index); var keep = new TreeMap<>(pf.layers);
            pf.layers = new TreeMap<>(keep);
            pf.layers.entrySet().removeIf(e -> e.getValue().instanceName != null
                || e.getValue().getCharacter() instanceof DefineEditTextTag);
            render(pan,index,bounds,"portrait-"+(index+1)+".png"); pf.layers = keep;
        }
        var mask = ((DefineSpriteTag)swf.getCharacter(533));
        render(mask.getTimeline(),1,mask.getRect(),"eliminated.png");
        var b=mask.getRect();
        String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(Path.of(args[0]))));
        Files.writeString(output.resolve("manifest.json"), "{\"source_sha256\":\""+hash+"\",\"zoom\":2,\"root_frame\":9,\"portrait_bounds\":[-40,-40,80,80],\"mask_bounds\":["+b.Xmin/20.0+","+b.Ymin/20.0+","+b.getWidth()/20.0+","+b.getHeight()/20.0+"]}\n");
        System.out.println("Exported original HUD background, four portraits and eliminated overlay at 2x.");
        System.exit(0);
    }
}
