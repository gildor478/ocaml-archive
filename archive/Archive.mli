(** High-level archive handling
    @author Sylvain Le Gall *)

open ArchiveLow

type filename = string

(** Read-only archive *)
module Read : sig
  (** This module allow to manipulate a read-only archive. Beware that the data
      defined in [input] will be used at creation to scan the content of the
      archive and then will be reused to fetch content. This means that the
      matching file can be open more than once. *)

  type ('a, 'b) input =
    [ `Callback of
      'a
      * ('a, 'b) open_callback
      * 'b read_callback
      * 'b skip_callback
      * 'b close_callback
      (** Use callbacks and archive_read_open2 to create the archive *)
    | `Filename of filename  (** Use a filename to create the archive *) ]

  type ('a, 'b) t

  val create : ('a, 'b) input -> ('a, 'b) t
  (** Create the archive and do an initial scan of the content *)

  val file_exists : ('a, 'b) t -> filename -> bool
  (** Test file existence in the archive *)

  val stat : ('a, 'b) t -> filename -> Unix.LargeFile.stats
  (** Get Unix statistics about a filename in the archive *)

  val is_directory : ('a, 'b) t -> filename -> bool
  (** Test if a filename is a directory *)

  val entry : ('a, 'b) t -> filename -> Entry.t
  (** Get the entry of a filename *)

  val with_file :
    ('a, 'b) t ->
    filename ->
    (Entry.t -> 'c) ->
    ('c -> string -> int -> 'c) ->
    ('c -> 'd) ->
    'd
  (** [with_file t fn open read close] Read the content of a file, use the
      callbacks function [open], [read] and [close] to push the data. *)

  val content : ('a, 'b) t -> filename -> string
  (** [content t fn] Simplified version of {!with_file}, using a [Buffer.t] and
      returning its content. *)

  val readdir : ('a, 'b) t -> filename -> filename array
  (** List content of a directory *)
end
