use std::error::Error;
use std::{env, path::PathBuf};


fn main() -> Result<(), Box<dyn Error>> {
    let proto_file = "proto/centrium.proto";
    let out_dir = PathBuf::from(std::env::var("OUT_DIR").unwrap());

    // Check if proto file exists
    if !PathBuf::from(proto_file).exists() {
        return Err(format!("Proto file {} not found", proto_file).into());
    }

    let proto_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("proto");
    tonic_build::configure()
        .file_descriptor_set_path(out_dir.join("centrium_descriptor.bin"))
        .compile(&[proto_dir.join("centrium.proto")], &[proto_dir])?;


    Ok(())
}
