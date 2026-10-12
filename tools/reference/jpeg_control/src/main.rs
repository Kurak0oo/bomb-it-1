// The same pinned JPEG decoder as the captured Ruffle build. Diagnostic only.
use std::{env, fs, io::Cursor, path::Path};
fn main() {
    for argument in env::args().skip(1) {
        let path=Path::new(&argument);
        let bytes=fs::read(&path).unwrap();
        let mut decoder=jpeg_decoder::Decoder::new(Cursor::new(bytes));
        let rgb=decoder.decode().unwrap();
        fs::write(path.with_extension("rgb"),rgb).unwrap();
    }
}
