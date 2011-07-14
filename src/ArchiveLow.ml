
(** Low level function to libarchive
  *
  * This is the low level function which are almost a 1:1 mapping of libarchive
  * functions. 
  *
  * Callbacks should only raise an {!AFailure} exception, this way they will
  * trigger an [archive_set_error]. Any other exceptions will be mapped to a
  * generic exception when setting error.
  *
  * @author Sylvain Le Gall
  *)

type 'a archive 

type filename = string

type error_code = int

(* archive_read_open2 open callback *)
type ('a, 'b) open_callback = 'a -> 'b

(* archive_read_open2 read callback *)
type 'a read_callback = 'a -> string -> int 

(* archive_read_open2 skip callback *)
type 'a skip_callback = 'a -> int -> int

(* archive_read_open2 close callback *)
type 'a close_callback = 'a -> unit

exception AEnd_of_file
exception AFailure of error_code * string

external init: unit -> unit = "caml_archive_init"

let is_inited = ref false

let init () =
  if not !is_inited then
    begin
      Callback.register_exception "archive eof" AEnd_of_file;
      Callback.register_exception "archive.failure" (AFailure (0, "foo"));
      init ();
      is_inited := true
    end


let () = 
  init ()

module Entry =
struct 
  type t

  external create: unit -> t =
      "caml_archive_entry_create"

  external clone: t -> t =
      "caml_archive_entry_clone"

  external pathname: t -> filename =
      "caml_archive_entry_pathname"

  external stat: t -> Unix.LargeFile.stats =
      "caml_archive_entry_stat"
end

module Read =
struct 
  type t = [`Read] archive 
  
  (** archive_read_new *)
  external create: unit -> t = 
      "caml_archive_read_create"

  (** archive_read_support_filter_all *)
  external support_filter_all: t -> unit = 
    "caml_archive_read_support_filter_all"

  (** archive_read_support_compress_all *)
  external support_format_all: t -> unit = 
    "caml_archive_read_support_format_all"

  (** archive_read_open_filename *)
  external open_filename: t -> filename -> int -> unit = 
    "caml_archive_read_open_filename"

  (** archive_read_open2 *)
  external open2: 
      t -> 
    ('a, 'b) open_callback -> 
    'b read_callback -> 
    'b skip_callback -> 
    'b close_callback ->
    'a -> unit = 
      "caml_archive_read_open2_bytecode" "caml_archive_read_open2_native"

  external next_header2: t -> Entry.t -> bool =
    "caml_archive_read_next_header2"

  external data_skip: t -> unit =
    "caml_archive_read_data_skip"

  external data: t -> string -> int -> int -> int =
    "caml_archive_read_data"

  external close: t -> unit =
    "caml_archive_read_close"

end
