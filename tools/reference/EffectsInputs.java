import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.ShapeTag;
import com.jpexs.decompiler.flash.tags.base.ImageTag;
import com.jpexs.decompiler.flash.types.MATRIX;

/** Retain source display-list inputs and raw premultiplied lossless channels. */
class EffectsInputs {
    static String matrix(MATRIX m) {
        if (m == null) return "[1,0,0,1,0,0]";
        return "["+m.getScaleXFloat()+","+m.getRotateSkew0Float()+","+m.getRotateSkew1Float()+","+m.getScaleYFloat()+","+m.translateX/20.0+","+m.translateY/20.0+"]";
    }
    public static void main(String[] args) throws Exception {
        var swf = new SWF(new FileInputStream(args[0]),false);
        var output = Path.of(args[1]); Files.createDirectories(output);
        var shapes = new ArrayList<String>(); var timelines = new ArrayList<String>(); var gradients = new ArrayList<String>();
        for (var tag : swf.getCharacters(false).values()) {
            if (tag instanceof ShapeTag shape && (shape.getCharacterId()==232 ||
                shape.getCharacterId()>=239 && shape.getCharacterId()<=272 ||
                shape.getCharacterId()>=280 && shape.getCharacterId()<=285 ||
                shape.getCharacterId()>=328 && shape.getCharacterId()<=370)) {
                var fills = new ArrayList<String>();
                var styles = new ArrayList<com.jpexs.decompiler.flash.types.FILLSTYLE>(Arrays.asList(shape.getShapes().fillStyles.fillStyles));
                for (var record : shape.getShapes().shapeRecords) {
                    if (record instanceof com.jpexs.decompiler.flash.types.shaperecords.StyleChangeRecord change && change.stateNewStyles)
                        styles.addAll(Arrays.asList(change.fillStyles.fillStyles));
                }
                int fillIndex=0;
                for (var fill : styles) {
                    fillIndex++;
                    if (fill.hasGradient()) gradients.add("\""+shape.getCharacterId()+"_"+fillIndex+"\":"+matrix(fill.gradientMatrix));
                    if (!fill.hasBitmap()) continue;
                    if (!(swf.getCharacter(fill.bitmapId) instanceof ImageTag bitmapTag)) continue;
                    BufferedImage image;
                    if (bitmapTag instanceof DefineBitsLossless2Tag bitmap) {
                        if (bitmap.bitmapFormat != DefineBitsLossless2Tag.FORMAT_32BIT_ARGB) throw new Exception("Unexpected bitmap format");
                        image = new BufferedImage(bitmap.bitmapWidth,bitmap.bitmapHeight,BufferedImage.TYPE_INT_ARGB);
                        image.setRGB(0,0,bitmap.bitmapWidth,bitmap.bitmapHeight,bitmap.getBitmapData().bitmapPixelData,0,bitmap.bitmapWidth);
                    } else {
                        image=bitmapTag.getImageCached().getBufferedImage();
                        if (bitmapTag instanceof DefineBitsJPEG3Tag jpeg) {
                            Files.write(output.resolve("raw-"+fill.bitmapId+".jpg"),jpeg.getOriginalImageData().readAllBytes());
                            Files.write(output.resolve("raw-"+fill.bitmapId+".alpha"),jpeg.getImageAlpha());
                        }
                    }
                    ImageIO.write(image,"png",output.resolve("raw-"+fill.bitmapId+".png").toFile());
                    if (bitmapTag instanceof DefineBitsLossless2Tag bitmap) {
                        var rgba=new ByteArrayOutputStream();
                        for(int pixel:bitmap.getBitmapData().bitmapPixelData) {
                            rgba.write(pixel>>>16); rgba.write(pixel>>>8); rgba.write(pixel); rgba.write(pixel>>>24);
                        }
                        Files.write(output.resolve("raw-"+fill.bitmapId+".rgba"),rgba.toByteArray());
                    }
                    fills.add("{\"bitmap\":"+fill.bitmapId+",\"tag\":\""+bitmapTag.getClass().getSimpleName()+"\",\"fill_type\":"+fill.fillStyleType+",\"matrix\":"+matrix(fill.bitmapMatrix)+"}");
                }
                shapes.add("\""+shape.getCharacterId()+"\":["+String.join(",",fills)+"]");
            }
        }
        for (int id : new int[]{248,273,293,326,371}) {
            var timeline=((DefineSpriteTag)swf.getCharacter(id)).getTimeline(); var frames=new ArrayList<String>();
            for(int f=0;f<timeline.getFrameCount();f++) {
                var layers=new ArrayList<String>();
                for(var entry : new TreeMap<>(timeline.getFrame(f).layers).entrySet()) {
                    var layer=entry.getValue();
                    layers.add("{\"symbol\":"+layer.characterId+",\"depth\":"+entry.getKey()+",\"matrix\":"+matrix(layer.matrix)+",\"alpha\":"+(layer.colorTransForm==null?1:layer.colorTransForm.getAlphaMulti()/256.0)+"}");
                }
                frames.add("["+String.join(",",layers)+"]");
            }
            timelines.add("\""+id+"\":["+String.join(",",frames)+"]");
        }
        Files.writeString(output.resolve("inputs.json"),"{\"shapes\":{"+String.join(",",shapes)+"},\"timelines\":{"+String.join(",",timelines)+"},\"gradients\":{"+String.join(",",gradients)+"}}");
        System.out.println("Extracted original ordinary-effect drawing inputs and raw lossless bitmap channels.");
        System.exit(0);
    }
}
