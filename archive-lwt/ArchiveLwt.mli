(** Lwt version of {!Archive}
    @author Sylvain Le Gall *)

open ArchiveLow

(* Lwt version of {!ArchiveLow.Read.open_callback} *)
type ('a, 'b) open_callback = 'a -> 'b Lwt.t

(* Lwt version of {!Archivelow.Read.read_callback} *)
type 'a read_callback = 'a -> string -> int Lwt.t

(* Lwt version of {!ArchiveLow.Read.skip_callback} *)
type 'a skip_callback = 'a -> int -> int Lwt.t

(* Lwt version of {!ArchiveLow.Read.close_callback} *)
type 'a close_callback = 'a -> unit Lwt.t

module Read : sig
  type ('a, 'b) input =
    [ `Callback of
      ('a, 'b) open_callback
      * 'b read_callback
      * 'b skip_callback
      * 'b close_callback
      * 'a
    | `Filename of filename ]
  (** See {!Archive.Read.input} *)

  type ('a, 'b) t

  val create : ('a, 'b) input -> ('a, 'b) t Lwt.t
  (** See {!Archive.Read.create} *)

  val file_exists : ('a, 'b) t -> filename -> bool
  (** See {!Archive.Read.file_exists} *)

  val stat : ('a, 'b) t -> filename -> Unix.LargeFile.stats
  (** See {!Archive.Read.stat} *)

  val is_directory : ('a, 'b) t -> filename -> bool
  (** See {!Archive.Read.is_directory} *)

  val entry : ('a, 'b) t -> filename -> Entry.t
  (** See {!Archive.Read.entry} *)

  val with_file :
    ('a, 'b) t ->
    filename ->
    (Entry.t -> 'c Lwt.t) ->
    ('c -> string -> int -> 'c Lwt.t) ->
    ('c -> 'd Lwt.t) ->
    'd Lwt.t
  (** See {!Archive.Read.with_file} *)

  val content : ('a, 'b) t -> filename -> string Lwt.t
  (** See {!Archive.Read.content} *)

  val readdir : ('a, 'b) t -> filename -> filename array
  (** See {!Archive.Read.readdir} *)
end
