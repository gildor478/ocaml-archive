ocaml-archive - Binding to libarchive
=====================================

[![OCaml-CI Build Status](https://img.shields.io/endpoint?url=https://ci.ocamllabs.io/badge/gildor478/ocaml-archive/master&logo=ocaml)](https://ci.ocamllabs.io/github/gildor478/ocaml-archive)

libarchive is a C library for reading and writing tar, cpio, zip, ISO, and
other archive formats. This library is its OCaml bindings.

 * Reads a variety of formats, including tar, pax, cpio, zip, xar, lha, ar,
   cab, mtree, and ISO images.
 * Writes tar, pax, cpio, zip, xar, ar, ISO, mtree, and shar archives.
 * Full automatic format detection when reading archives, including
   compressed archives.

[libarchive website](http://code.google.com/p/libarchive/)

Installation
------------

The recommended way to install ocaml-archive is via [opam]:

```sh
$ opam install archive archive-lwt
```

Documentation
-------------

API documentation is
[available online](https://gildor478.github.io/ocaml-archive).

Copyright and license
---------------------

ocaml-archive is distributed under the terms of the GNU Lesser General Public
License version 2.1 with OCaml linking exception.
