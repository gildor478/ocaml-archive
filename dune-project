(lang dune 3.17)

(name ocaml-archive)

(generate_opam_files true)

(source
 (github gildor478/ocaml-archive))

(authors "Sylvain Le Gall")
(maintainers "Sylvain Le Gall <sylvain+ocaml@le-gall.net>")

(license "LGPL-2.1-or-later WITH OCaml-LGPL-linking-exception")

(package
 (name archive)
 (synopsis "Binding to libarchive")
 (description
"\|  libarchive is a C library for reading and writing tar, cpio, zip, ISO, and
"\|  other archive formats. This library is its OCaml bindings.
"\|
"\|  * Reads a variety of formats, including tar, pax, cpio, zip, xar, lha, ar,
"\|    cab, mtree, and ISO images.
"\|  * Writes tar, pax, cpio, zip, xar, ar, ISO, mtree, and shar archives.
"\|  * Full automatic format detection when reading archives, including
"\|    compressed archives.
"\|
"\|  [libarchive website](http://code.google.com/p/libarchive/)
)
 (depends
   (ocaml (>= 4.14.1))
   (fileutils (>= 0.6.6))
   (extlib (and (>= 1.8.0) :with-test))
   (ounit2 (and (>= 2.2.7) :with-test))))

(package
  (name archive-lwt)
  (synopsis "Binding to libarchive for LWT")
 (description
"\|  libarchive is a C library for reading and writing tar, cpio, zip, ISO, and
"\|  other archive formats. This library is its OCaml bindings.
"\|
"\|  * Reads a variety of formats, including tar, pax, cpio, zip, xar, lha, ar,
"\|    cab, mtree, and ISO images.
"\|  * Writes tar, pax, cpio, zip, xar, ar, ISO, mtree, and shar archives.
"\|  * Full automatic format detection when reading archives, including
"\|    compressed archives.
"\|
"\|  [libarchive website](http://code.google.com/p/libarchive/)
)
  (depends
    (ocaml (>= 4.14.1))
    (archive (= :version))
    (lwt (>= 2.3.2))
    (extlib (and (>= 1.8.0) :with-test))
    (ounit2 (and (>= 2.2.7) :with-test))))
