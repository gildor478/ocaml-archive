module C = Configurator.V1

let () =
  C.main ~name:"libarchive-pkg-config" (fun c ->
      let default : C.Pkg_config.package_conf =
        { libs = [ "-larchive" ]; cflags = [] }
      in
      let conf =
        match C.Pkg_config.get c with
        | None -> default
        | Some pc -> (
            match C.Pkg_config.query pc ~package:"libarchive" with
            | None -> default
            | Some deps -> deps)
      in
      C.Flags.write_sexp "flags.sexp" conf.cflags;
      C.Flags.write_sexp "library_flags.sexp" conf.libs)
