
open Lwt

(* Lwt version of {!ArchiveLow.Read.open_callback} *)
type ('a, 'b) open_callback = 'a -> 'b Lwt.t

(* Lwt version of {!Archivelow.Read.read_callback} *)
type 'a read_callback = 'a -> string -> int Lwt.t

(* Lwt version of {!ArchiveLow.Read.skip_callback} *)
type 'a skip_callback = 'a -> int -> int Lwt.t

(* Lwt version of {!ArchiveLow.Read.close_callback} *)
type 'a close_callback = 'a -> unit Lwt.t

module Read =
struct 
  module StdRead = Archive.Read
                     
  type ('a, 'b) input =
      [ `Callback of
          ('a, 'b) open_callback *
          'b read_callback *
          'b skip_callback *
          'b close_callback * 
          'a
      | `Filename of string ]

    type ('a, 'b) t = ('a, 'b) StdRead.t

  let create input = 
    let input' = 
      match input with 
        | `Callback (data, open_cbk, read_cbk, skip_cbk, close_cbk) -> 
            assert(false)

        | `Filename fn ->
            `Filename fn
    in
      Lwt_preemptive.detach 
        StdRead.create 
        input' 

  let file_exists  = StdRead.file_exists
  let stat         = StdRead.stat 
  let is_directory = StdRead.is_directory
  let readdir      = StdRead.readdir 
  let entry        = StdRead.entry

  let content t fn = 
    Lwt_preemptive.detach
      (StdRead.content t)
      fn

  let with_file t fn finit fread fclose = 
    finit (entry t fn)
    >>= fun data ->
    begin
      let q = Queue.create () in
      let rdata = ref data in
      let id =
        Lwt_unix.make_notification 
          (fun () -> 
             Lwt.ignore_result 
               (let str = Queue.pop q in
                  fread !rdata str (String.length str)
                  >|= fun data ->
                  rdata := data))
      in
      let fread' () buf len =
        Queue.push (String.sub buf 0 len) q;
        Lwt_unix.send_notification id
      in
        finalize
          (fun () ->
             Lwt_preemptive.detach 
               (fun () -> StdRead.with_file t fn ignore fread' ignore)
               ()
             >>= fun () ->
             fclose !rdata)

          (fun () ->
             Lwt_unix.stop_notification id;
             return ())
    end
    
end
