
type filename = string 

module MapString = Map.Make (String)

open Unix
open Unix.LargeFile

let () = 
  ArchiveLow.init ()

module Read = 
struct 
  type ('a, 'b) input = 
    [ `Filename of string
    | `Callback of 'a *
                   ('a, 'b) ArchiveLow.open_callback * 
                   'b ArchiveLow.read_callback *
                   'b ArchiveLow.skip_callback *
                   'b ArchiveLow.close_callback 
    ]

  type ('a, 'b) t = 
      {
        ard_input: ('a, 'b) input;
        ard_tree:  ArchiveLow.Entry.t MapString.t;
      }

  let with_low_arch input f = 
    let hdl = ArchiveLow.Read.create () in
      try 
        let () = 
          ArchiveLow.Read.support_filter_all hdl;
          ArchiveLow.Read.support_format_all hdl;
          match input with 
            | `Filename fn ->
                ArchiveLow.Read.open_filename hdl fn 4096
            | `Callback (data, open_cbk, read_cbk, skip_cbk, close_cbk) ->
                ArchiveLow.Read.open2 hdl open_cbk read_cbk skip_cbk close_cbk data
        in
        let res = f hdl in
          ArchiveLow.Read.close hdl;
          res

      with e ->
        ArchiveLow.Read.close hdl;
        raise e

  let with_low_fn t fn f = 
    try 
      let path = 
        ArchiveLow.Entry.pathname 
          (MapString.find fn t.ard_tree)
      in
        with_low_arch t.ard_input
          (fun hdl ->
             let ent = ArchiveLow.Entry.create () in

             let rec find () = 
               if ArchiveLow.Read.next_header2 hdl ent then
                 begin
                   if ArchiveLow.Entry.pathname ent = path then
                     f hdl ent
                   else
                     find ()
                 end
               else
                 raise Not_found
             in
               find ())
    with Not_found ->
      raise (Unix_error(ENOENT, "open", fn))


  let create input = 
    with_low_arch input
      (fun hdl ->
         let ent = ArchiveLow.Entry.create () in
         let rec fold acc = 
           if ArchiveLow.Read.next_header2 hdl ent then
             fold
               (MapString.add 
                  (FilePath.reduce (ArchiveLow.Entry.pathname ent))
                  (ArchiveLow.Entry.clone ent)
                  acc)
           else
             acc
         in
           {
             ard_input = input;
             ard_tree  = fold MapString.empty;
           })

  let file_exists t fn =
    MapString.mem fn t.ard_tree

  let stat t fn =
    try 
      ArchiveLow.Entry.stat
        (MapString.find fn t.ard_tree)
    with Not_found ->
      raise (Unix_error(ENOENT, "stat", fn))

  let is_directory t fn =
      (stat t fn).st_kind = S_DIR

  let with_file t fn finit fread fclose =
    with_low_fn t fn 
      (fun hdl ent ->
         let str = String.make 4096 '\000' in
         let read () = ArchiveLow.Read.data hdl str 0 (String.length str) in
         let acc = ref (finit ent) in
         let byte_read = ref (read ()) in
           while !byte_read > 0 do 
             acc := fread !acc str !byte_read;
             byte_read := read ()
           done;
           fclose !acc)

  let entry t fn =
    MapString.find fn t.ard_tree

  let content t fn =
    with_file t fn
      (fun ent ->
         Buffer.create 
           (Int64.to_int 
              (ArchiveLow.Entry.stat ent).st_size))
      (fun buf str len ->
         Buffer.add_substring buf str 0 len;
         buf)
      (fun buf ->
         Buffer.contents buf)

  let readdir t fn = 
    let lst = 
      MapString.fold
        (fun fn' _ acc ->
           let dn' = FilePath.dirname fn' in
           if (FilePath.is_current fn && FilePath.is_current dn') ||
              FilePath.compare dn' fn = 0 then
             (FilePath.basename fn') :: acc
           else
             acc)
        t.ard_tree
        []
    in
      Array.of_list lst

end
