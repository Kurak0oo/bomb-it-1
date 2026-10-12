import java.io.*; import com.jpexs.decompiler.flash.SWF; import com.jpexs.decompiler.flash.tags.DefineFont2Tag;
class FontMetrics { public static void main(String[] a)throws Exception{var s=new SWF(new FileInputStream(a[0]),false);var f=(DefineFont2Tag)s.getCharacters(false).get(295);System.out.println("layout="+f.fontFlagsHasLayout+",ascent="+f.fontAscent+",descent="+f.fontDescent+",leading="+f.fontLeading);for(int i=0;i<f.codeTable.size();i++)System.out.println("code="+f.codeTable.get(i)+",bounds="+f.glyphShapeTable.get(i).getBounds(1));System.exit(0);}}

