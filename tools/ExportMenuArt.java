import java.io.*;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
import javax.imageio.ImageIO;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.DefineSpriteTag;
import com.jpexs.decompiler.flash.tags.base.ButtonTag;
import com.jpexs.decompiler.flash.timeline.*;
import com.jpexs.decompiler.flash.types.*;
import com.jpexs.decompiler.flash.exporters.commonshape.Matrix;

/** Render original display-list segments around interactive placements, at 2x.
 * Labels/decorations stay at their original depths above button backgrounds.
 * This extracts artwork only and never executes or rewrites game rules. */
class ExportMenuArt {
    static final double ZOOM = 2;
    static Path output;

    static String json(Object value) {
        if (value instanceof Map<?,?> map) {
            var entries = new ArrayList<String>();
            map.entrySet().stream().sorted(Comparator.comparing(entry -> entry.getKey().toString()))
                .forEach(entry -> entries.add(json(entry.getKey().toString()) + ":" + json(entry.getValue())));
            return "{" + String.join(",", entries) + "}";
        }
        if (value instanceof List<?> list) return "[" + String.join(",", list.stream().map(ExportMenuArt::json).toList()) + "]";
        if (value instanceof String text) return "\"" + text.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
        return value.toString();
    }

    static void render(Timeline timeline, int frame, RECT bounds, String name) throws Exception {
        var image = SWF.frameToImageGet(timeline, frame, 0, null, 0, bounds,
            new Matrix(), new ColorTransform(), null, ZOOM, true, 1);
        ImageIO.write(image.getBufferedImage(), "png", output.resolve(name).toFile());
    }

    static Map<String,Object> placement(DepthState state, RECT bounds) {
        var m = new Matrix(state.matrix);
        var row = new LinkedHashMap<String,Object>();
        row.put("symbol", state.characterId);
        row.put("matrix", List.of(m.scaleX, m.rotateSkew0, m.rotateSkew1, m.scaleY,
                                 m.translateX / 20, m.translateY / 20));
        row.put("bounds", List.of(bounds.Xmin/20.0, bounds.Ymin/20.0,
                                 bounds.getWidth()/20.0, bounds.getHeight()/20.0));
        return row;
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 2) throw new IllegalArgumentException("Usage: ExportMenuArt <source.swf> <output>");
        output = Path.of(args[1]);
        Files.createDirectories(output);
        var swf = new SWF(new FileInputStream(args[0]), false);
        var timeline = swf.getTimeline();
        var screens = new LinkedHashMap<String,Object>();
        var names = List.of("menu", "players", "help", "powerups");
        var numbers = List.of(3, 4, 6, 7);
        var exported = new HashSet<Integer>();
        for (int n=0; n<names.size(); n++) {
            String name = names.get(n);
            int index = numbers.get(n)-1;
            var frame = timeline.getFrame(index);
            var original = new TreeMap<>(frame.layers);
            var segment = new TreeMap<Integer,DepthState>();
            var layers = new ArrayList<Map<String,Object>>();
            int sequence = 0;
            for (var entry : original.entrySet()) {
                var state = entry.getValue();
                var character = state.getCharacter();
                boolean interactive = character instanceof ButtonTag || state.characterId == 455 || state.characterId == 460;
                if (!interactive) { segment.put(entry.getKey(), state); continue; }
                if (!segment.isEmpty()) {
                    String image = name + "-layer-" + sequence++ + ".png";
                    frame.layers = segment;
                    render(timeline, index, swf.displayRect, image);
                    layers.add(Map.of("kind", "static", "image", image));
                    segment = new TreeMap<>();
                }
                Timeline child;
                RECT bounds;
                int count;
                String kind;
                if (character instanceof ButtonTag button) {
                    child = button.getTimeline(); bounds = button.getRect(); count = 3; kind = "button";
                } else {
                    var sprite = (DefineSpriteTag) character;
                    child = sprite.getTimeline(); bounds = sprite.getRect();
                    count = state.characterId == 460 ? 2 : 1;
                    kind = state.characterId == 460 ? "sound" : "quality";
                }
                if (exported.add(state.characterId)) {
                    for (int f=0; f<count; f++) render(child, f, bounds, state.characterId + "-" + f + ".png");
                }
                var row = placement(state, bounds);
                row.put("kind", kind);
                row.put("frames", count);
                layers.add(row);
            }
            if (!segment.isEmpty()) {
                String image = name + "-layer-" + sequence + ".png";
                frame.layers = segment;
                render(timeline, index, swf.displayRect, image);
                layers.add(Map.of("kind", "static", "image", image));
            }
            frame.layers = original;
            screens.put(name, Map.of("root_frame", index+1, "layers", layers));
        }
        var manifest = new LinkedHashMap<String,Object>();
        manifest.put("source_sha256", HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(Path.of(args[0])))));
        manifest.put("zoom", ZOOM);
        manifest.put("screens", screens);
        Files.writeString(output.resolve("manifest.json"), json(manifest) + "\n");
        System.out.println("Exported four original menu/help screens and their button states at 2x.");
        System.exit(0);
    }
}
