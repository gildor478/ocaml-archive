open OUnit
open Lwt

let ls_alR arch is_dir readdir =
  let rec ls_alR' acc dn =
    Array.fold_left
      (fun acc bn ->
        let fn = FilePath.concat dn bn in
        if is_dir arch fn then ls_alR' acc fn else fn :: acc)
      acc (readdir arch dn)
  in
  List.sort String.compare (ls_alR' [] "")

let read_tarball arch dump_fn =
  let lst = ls_alR arch Archive.Read.is_directory Archive.Read.readdir in
  let dump = Archive.Read.content arch dump_fn in
  (lst, dump)

let read_tarball_lwt input dump_fn =
  ArchiveLwt.Read.create input >>= fun arch ->
  let lst = ls_alR arch ArchiveLwt.Read.is_directory ArchiveLwt.Read.readdir in
  ArchiveLwt.Read.content arch dump_fn >|= fun ctnt -> (lst, ctnt)

module ListString = OUnitDiff.ListSimpleMake (struct
  type t = string

  let compare = String.compare
  let pp_printer = Format.pp_print_string
  let pp_print_sep = OUnitDiff.pp_comma_separator
end)

let unix_input fn =
  `Callback_seekable (
    fn,
    (* Open callback *)
    (fun fn -> Unix.openfile fn [Unix.O_RDONLY] 0),
    (* Read callback *)
    (fun fd buf -> Unix.read fd buf 0 (Bytes.length buf)),
    (* Skip callback *)
    (fun fd request ->
      ignore (Unix.lseek fd request Unix.SEEK_CUR);
      request),
    (* Close callback *)
    (fun fd -> Unix.close fd),
    (* Seek callback *)
    Unix.lseek
  )

let ([] | _ :: _) =
  let cc = Filename.concat in
  run_test_tt_main
    ("ocaml-archive"
    >::: [
           ( "Simple" >:: fun () ->
             let _, dump =
               read_tarball
                 (Archive.Read.create
                    (`Filename "data/ocaml-data-notation-0.0.6.tar.gz"))
                 (cc "ocaml-data-notation-0.0.6" "_oasis")
             in
             assert_equal ~msg:"Digest of _oasis"
               ~printer:(fun s -> s)
               "c9b290271ca1da665261520256a8a7a1"
               (Digest.to_hex (Digest.string dump)) );
           ( "BadFile" >:: fun () ->
             let msg =
               try
                 let _arch =
                   Archive.Read.create (`Filename "data/Makefile.bz2")
                 in
                 assert_failure "Expecting to fail"
               with ArchiveLow.AFailure (_, msg) -> msg
             in
             assert_equal ~msg:"Exception message"
               ~printer:(fun s -> s)
               "Unrecognized archive format" msg );
           ( "read_open2" >:: fun () ->
             let exp_lst, exp_dump =
               read_tarball
                 (Archive.Read.create
                    (`Filename "data/ocaml-data-notation-0.0.6.tar.gz"))
                 (cc "ocaml-data-notation-0.0.6" "_oasis")
             in
             let lst, dump =
               read_tarball
                 (Archive.Read.create
                    (`Callback
                       ( "data/ocaml-data-notation-0.0.6.tar.gz",
                         (* Open callback *)
                         (fun fn -> open_in_bin fn),
                         (* Read callback *)
                         (fun chn buf -> input chn buf 0 (Bytes.length buf)),
                         (* Skip callback *)
                         (fun chn off ->
                           let start = pos_in chn in
                           seek_in chn (start + off);
                           pos_in chn - start),
                         (* Close callback *)
                         fun chn -> close_in chn )))
                 (cc "ocaml-data-notation-0.0.6" "_oasis")
             in
             ListString.assert_equal ~msg:"directory listing" exp_lst lst;
             ListString.assert_equal ~msg:"_oasis content"
               (ExtLib.String.nsplit exp_dump "\n")
               (ExtLib.String.nsplit dump "\n") );
           ( "lwt" >:: fun () ->
             let exp_lst, exp_dump =
               read_tarball
                 (Archive.Read.create
                    (`Filename "data/ocaml-data-notation-0.0.6.tar.gz"))
                 (cc "ocaml-data-notation-0.0.6" "_oasis")
             in
             let lst, dump =
               Lwt_main.run
                 (read_tarball_lwt
                    (`Filename "data/ocaml-data-notation-0.0.6.tar.gz")
                    (cc "ocaml-data-notation-0.0.6" "_oasis"))
             in
             ListString.assert_equal ~msg:"directory listing" exp_lst lst;
             ListString.assert_equal ~msg:"_oasis content"
               (ExtLib.String.nsplit exp_dump "\n")
               (ExtLib.String.nsplit dump "\n") );
           ( "seek" >:: fun () ->
             let exp_lst, exp_dump =
               read_tarball
                 (Archive.Read.create
                    (`Filename "data/ocaml-data-notation-0.0.6.tar.gz"))
                 (cc "ocaml-data-notation-0.0.6" "_oasis")
             in
             let lst, dump =
               read_tarball
                 (Archive.Read.create (unix_input "data/ocaml-data-notation-0.0.6.tar.gz"))
                 (cc "ocaml-data-notation-0.0.6" "_oasis")
             in
             ListString.assert_equal ~msg:"directory listing" exp_lst lst;
             ListString.assert_equal ~msg:"_oasis content"
               (ExtLib.String.nsplit exp_dump "\n")
               (ExtLib.String.nsplit dump "\n") );
           ( "NoCloseAfterFailedOpen" >:: fun () ->
             let a = ArchiveLow.Read.create () in
             let () =
               try
                 let boom () = raise (ArchiveLow.AFailure (42, "message")) in
                 let z _ _ = 0 in
                 ArchiveLow.Read.open2 a boom z z ignore ()
                 (* if the test fails, open2 will SEGFAULT *)
               with ArchiveLow.AFailure (code, msg) ->
                 assert_equal (code, msg) (42, "message")
             in
             ArchiveLow.Read.close a );
         ])
