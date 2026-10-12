import java.io.*;
import java.nio.file.*;
import java.util.*;
import javax.imageio.ImageIO;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.timeline.*;
import com.jpexs.decompiler.flash.types.*;
import com.jpexs.decompiler.flash.exporters.commonshape.Matrix;

/** Source-only outcome and score artwork, with original dynamic-field geometry. */
class ExportResultsArt {
 static Path out; static SWF swf;
 static String json(Object v) {
  if(v instanceof Map<?,?> m) {var rows=new ArrayList<String>();for(var e:m.entrySet())rows.add(json(e.getKey().toString())+":"+json(e.getValue()));return "{"+String.join(",",rows)+"}";}
  if(v instanceof List<?> a)return "["+String.join(",",a.stream().map(ExportResultsArt::json).toList())+"]";
  if(v instanceof String s)return "\""+s.replace("\\","\\\\").replace("\"","\\\"")+"\"";
  return v.toString();
 }
 static void render(Timeline t,int f,RECT b,String name)throws Exception {
  ImageIO.write(SWF.frameToImageGet(t,f,0,null,0,b,new Matrix(),new ColorTransform(),null,2,true,1).getBufferedImage(),"png",out.resolve(name).toFile());
 }
 static Map<String,Object> part(int symbol,int index,Set<Integer> omit,String name)throws Exception {
  var sprite=(DefineSpriteTag)swf.getCharacter(symbol);var t=sprite.getTimeline();var frame=t.getFrame(index);var original=new TreeMap<>(frame.layers);
  var fields=new ArrayList<Map<String,Object>>();var buttons=new ArrayList<Map<String,Object>>();
  frame.layers=new TreeMap<>(original);
  for(var e:original.entrySet()) {
   var state=e.getValue();var m=new Matrix(state.matrix);
   if(state.getCharacter() instanceof DefineEditTextTag text) {
    var b=text.getBounds();
    fields.add(Map.of("name",text.variableName,"rect",List.of(m.translateX/20+b.Xmin/20.0,m.translateY/20+b.Ymin/20.0,b.getWidth()/20.0,b.getHeight()/20.0),"size",text.fontHeight/20.0,"align",text.align));
    frame.layers.remove(e.getKey());
   }
   if(omit.contains(state.characterId)) frame.layers.remove(e.getKey());
   if(state.getCharacter() instanceof ButtonTag button && state.characterId!=565) {
    var b=button.getRect();buttons.add(Map.of("symbol",state.characterId,"matrix",List.of(m.scaleX,m.rotateSkew0,m.rotateSkew1,m.scaleY,m.translateX/20,m.translateY/20),"bounds",List.of(b.Xmin/20.0,b.Ymin/20.0,b.getWidth()/20.0,b.getHeight()/20.0)));
   }
  }
  // Full source stage bounds in the sprite's root placement coordinates.
  RECT bounds=symbol==603?new RECT(-5500,5500,-4000,4000):sprite.getRect();
  render(t,index,bounds,name);frame.layers=original;
  return Map.of("fields",fields,"buttons",buttons,"bounds",List.of(bounds.Xmin/20.0,bounds.Ymin/20.0,bounds.getWidth()/20.0,bounds.getHeight()/20.0));
 }
 public static void main(String[] args)throws Exception {
  out=Path.of(args[1]);Files.createDirectories(out);swf=new SWF(new FileInputStream(args[0]),false);
  var data=new LinkedHashMap<String,Object>();
  for(int humans=1;humans<=2;humans++)data.put("scores"+humans,part(603,humans,Set.of(579),"scores-"+humans+".png"));
  var root=swf.getTimeline();var frame=root.getFrame(9);var keep=new TreeMap<>(frame.layers);frame.layers=new TreeMap<>(keep);frame.layers.entrySet().removeIf(e->e.getValue().characterId==629);render(root,9,swf.displayRect,"final-background.png");frame.layers=keep;
  for(int humans=1;humans<=2;humans++)data.put("final"+humans,part(629,humans-1,Set.of(611),"final-"+humans+".png"));
  for(int symbol:new int[]{562,579,611}) {
   var sp=(DefineSpriteTag)swf.getCharacter(symbol);var b=sp.getRect();
   data.put("symbol"+symbol,Map.of("bounds",List.of(b.Xmin/20.0,b.Ymin/20.0,b.getWidth()/20.0,b.getHeight()/20.0)));
   for(int f=0;f<sp.getTimeline().getFrameCount();f++)render(sp.getTimeline(),f,b,symbol+"-"+(f+1)+".png");
  }
  Files.writeString(out.resolve("manifest.json"),json(data)+"\n");
  System.out.println("Exported source result sheets, final screens and outcome banners.");System.exit(0);
 }
}
