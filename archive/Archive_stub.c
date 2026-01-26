
#include <caml/fail.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/callback.h>
#include <caml/memory.h>
#include <caml/unixsupport.h>
#include <caml/threads.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <archive.h>
#include <archive_entry.h>

#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define READ_BUFFER 4096

struct caml_archive {
  struct archive *archive;
  value open_cbk;
  value read_cbk;
  value skip_cbk;
  value seek_cbk;
  value close_cbk;
  value client_data;
  value client_data2;
  value buffer;
  char  buffer_c[READ_BUFFER];
};

typedef struct caml_archive *ptr_archive;
typedef struct archive_entry *ptr_archive_entry;

void caml_archive_check_error (int error, struct archive *arch)
{
  value args[2];

  CAMLparam0();
  switch (error)
  {
    case ARCHIVE_EOF:
      caml_raise_constant(*caml_named_value("archive.eof"));
      break;
    case ARCHIVE_OK:
      break;
    default:
      args[0] = Val_int(archive_errno(arch));
      args[1] = caml_copy_string(archive_error_string(arch));
      caml_raise_with_args(*caml_named_value("archive.failure"), 2, args);
      break;
  };
  CAMLreturn0;
};

/*
 * Entry
 */

#define Entry_val(v) ((ptr_archive_entry *) Data_custom_val(v))

void caml_archive_entry_finalize (value ventry)
{
  ptr_archive_entry *ptr = Entry_val(ventry);
  if (*ptr != NULL)
  {
    archive_entry_free(*ptr);
    *ptr = NULL;
  };
};

static struct custom_operations caml_archive_entry_ops = {
  "com.ocamlcore.archive.entry",
  caml_archive_entry_finalize,
  custom_compare_default,
  custom_hash_default,
  custom_serialize_default,
  custom_deserialize_default
};

CAMLprim value caml_archive_entry_create (value vunit)
{
  ptr_archive_entry *ptr = NULL;
  CAMLparam1(vunit);
  CAMLlocal1(vres);
  vres = caml_alloc_custom(&caml_archive_entry_ops,
      sizeof(ptr_archive_entry), 0, 1);
  ptr = Entry_val(vres);
  *ptr = archive_entry_new();
  if (*ptr == NULL)
  {
    caml_raise_with_string
      (*caml_named_value("archive.failure"),
       "Unable to allocate an archive_entry structure");
  };
  CAMLreturn(vres);
};

CAMLprim value caml_archive_entry_clone (value ventry)
{
  ptr_archive_entry *ptr1 = NULL, *ptr2 = NULL;
  CAMLparam1(ventry);
  CAMLlocal1(vres);
  vres = caml_alloc_custom(&caml_archive_entry_ops,
      sizeof(ptr_archive_entry), 0, 1);
  ptr1 = Entry_val(ventry);
  ptr2 = Entry_val(vres);
  *ptr2 = archive_entry_clone(*ptr1);
  CAMLreturn(vres);
}

CAMLprim value caml_archive_entry_pathname (value ventry)
{
  CAMLparam1(ventry);
  CAMLlocal1(vres);
  const char *c = archive_entry_pathname(*Entry_val(ventry));
  if (!c)
    caml_raise_with_string
      (*caml_named_value("archive.failure"),
       "null pathname");
  vres = caml_copy_string(c);
  CAMLreturn(vres);
}

/* same order as in otherlibs/unix/stat.c */
static int file_kind_table[] = {
  AE_IFREG, AE_IFDIR, AE_IFCHR, AE_IFBLK, AE_IFLNK, AE_IFIFO, AE_IFSOCK
};

static value stat_aux(const struct stat *buf)
{
  int i = 0;
  CAMLparam0();
  CAMLlocal5(atime, mtime, ctime, offset, v);

  atime = caml_copy_double((double) buf->st_atime);
  mtime = caml_copy_double((double) buf->st_mtime);
  ctime = caml_copy_double((double) buf->st_ctime);
  offset = caml_copy_int64(buf->st_size);
  v = caml_alloc_small(12, 0);
  Field (v, 0) = Val_int (buf->st_dev);
  Field (v, 1) = Val_int (buf->st_ino);
  for (i = 0; i < sizeof(file_kind_table) / sizeof(int); i++)
  {
    if ((buf->st_mode & S_IFMT) == file_kind_table[i])
    {
      Field (v, 2) = Val_int(i);
    }
  };
  Field (v, 3) = Val_int (buf->st_mode & 07777);
  Field (v, 4) = Val_int (buf->st_nlink);
  Field (v, 5) = Val_int (buf->st_uid);
  Field (v, 6) = Val_int (buf->st_gid);
  Field (v, 7) = Val_int (buf->st_rdev);
  Field (v, 8) = offset;
  Field (v, 9) = atime;
  Field (v, 10) = mtime;
  Field (v, 11) = ctime;
  CAMLreturn(v);
}

CAMLprim value caml_archive_entry_stat (value ventry)
{
  CAMLparam1(ventry);
  CAMLreturn(stat_aux(archive_entry_stat(*Entry_val(ventry))));
};

/*
 * Archive
 */

#define Archive_val(v) ((ptr_archive) Data_custom_val(v))

void caml_archive_finalize (value vread)
{
  ptr_archive ptr = Archive_val(vread);
  caml_remove_global_root(&(ptr->seek_cbk));
  if (ptr->archive != NULL)
  {
    archive_read_free(ptr->archive);
    ptr->archive = NULL;
  };
};

static struct custom_operations caml_archive_ops = {
  "com.ocamlcore.archive.read",
  caml_archive_finalize,
  custom_compare_default,
  custom_hash_default,
  custom_serialize_default,
  custom_deserialize_default
};

/*
 * Read
 */

CAMLprim value caml_archive_read_create (value vunit)
{
  ptr_archive ptr = NULL;
  CAMLparam1(vunit);
  CAMLlocal1(vres);

  vres = caml_alloc_custom(&caml_archive_ops,
      sizeof(struct caml_archive),
      0, 1);
  ptr = Archive_val(vres);
  caml_register_global_root(&(ptr->seek_cbk));
  ptr->seek_cbk = Val_unit;
  ptr->archive = archive_read_new ();
  if (ptr->archive == NULL)
  {
    caml_raise_with_string
      (*caml_named_value("archive.failure"),
       "Unable to allocate an archive structure");
  };
  CAMLreturn(vres);
};

CAMLprim value caml_archive_read_support_filter_all (value vread)
{
  ptr_archive ptr = NULL;
  CAMLparam1(vread);
  ptr = Archive_val(vread);
  caml_archive_check_error(
      archive_read_support_filter_all(ptr->archive),
      ptr->archive);
  CAMLreturn(Val_unit);
};

CAMLprim value caml_archive_read_support_format_all (value vread)
{
  ptr_archive ptr = NULL;
  CAMLparam1(vread);
  ptr = Archive_val(vread);
  caml_archive_check_error(
      archive_read_support_format_all(ptr->archive),
      ptr->archive);
  CAMLreturn(Val_unit);
};

CAMLprim value caml_archive_read_open_filename (value vread, value vfn, value vblock_size)
{
  ptr_archive ptr = NULL;
  int   res = ARCHIVE_OK;
  int   block_size = 0;
  CAMLparam3(vread, vfn, vblock_size);
  ptr = Archive_val(vread);
  const char *fn  = String_val(vfn);
  block_size = Int_val(vblock_size);

  caml_enter_blocking_section();
  res = archive_read_open_filename(ptr->archive, fn, block_size);
  caml_leave_blocking_section();

  caml_archive_check_error(res, ptr->archive);
  CAMLreturn(Val_unit);
};

CAMLprim value caml_archive_read_next_header2 (value vread, value ventry)
{
  int ret = 0;
  ptr_archive ptr = NULL;
  ptr_archive_entry *ptre = NULL;
  CAMLparam2(vread, ventry);
  CAMLlocal1(vres);
  ptr = Archive_val(vread);
  ptre = Entry_val(ventry);

  caml_enter_blocking_section();
  ret = archive_read_next_header2(ptr->archive, *ptre);
  caml_leave_blocking_section();

  switch (ret)
  {
    case ARCHIVE_OK:
      vres = Val_true;
      break;
    case ARCHIVE_EOF:
      vres = Val_false;
      break;
    default:
      caml_archive_check_error(ret, ptr->archive);
      break;
  }
  CAMLreturn(vres);
};

CAMLprim value caml_archive_read_data_skip (value vread)
{
  ptr_archive ptr = NULL;
  int res = ARCHIVE_OK;
  CAMLparam1(vread);
  ptr = Archive_val(vread);

  caml_enter_blocking_section();
  res = archive_read_data_skip(ptr->archive);
  caml_leave_blocking_section();

  caml_archive_check_error(res, ptr->archive);
  CAMLreturn(Val_unit);
};

CAMLprim value caml_archive_read_data (value vread, value vstr, value voff, value vlen)
{
  int size = 0;
  ptr_archive ptr = NULL;
  int off = 0, len = 0;

  CAMLparam4(vread, vstr, voff, vlen);

  ptr = Archive_val(vread);
  const char *str = String_val(vstr);
  off = Long_val(voff);
  len = Int_val(vlen);

  assert(caml_string_length(vstr) > off);
  assert(caml_string_length(vstr) >= off + len);
  assert(len >= 0);

  caml_enter_blocking_section();
  char *str_off = (char*)str + off;
  size = archive_read_data(ptr->archive, str_off, len);
  caml_leave_blocking_section();

  if (size < 0)
  {
    caml_archive_check_error(archive_errno(ptr->archive), ptr->archive);
  };
  CAMLreturn(Val_int(size));
};

CAMLprim value caml_archive_read_close (value vread)
{
  ptr_archive ptr = NULL;
  int res = ARCHIVE_OK;

  CAMLparam1(vread);
  ptr = Archive_val(vread);

  caml_enter_blocking_section();
  res = archive_read_close(ptr->archive);
  caml_leave_blocking_section();

  caml_archive_check_error(res, ptr->archive);
  CAMLreturn(Val_unit);
};


/*
 * read_open2 and all callbacks
 */

CAMLprim int caml_archive_set_error (struct archive *ptr, value vres)
{
  int res = 0;

  CAMLparam1(vres);
  CAMLlocal1(vexn);
  if (Is_exception_result(vres))
  {
    vexn = Extract_exception(vres);
    if (Wosize_val(vexn) == 3 && Field(vexn, 0) == *caml_named_value("archive.failure"))
    {
      assert(Is_long(Field(vexn, 1)));
      assert(Is_block(Field(vexn, 2)) && Tag_val(Field(vexn, 2)) == String_tag);
      archive_set_error(ptr, Int_val(Field(vexn, 1)), "%s", String_val(Field(vexn, 2)));
    }
    else
    {
      printf("Cannot decode exception\n"); fflush(stdout);
      archive_set_error(ptr, -1, "Unknown exception raised during callback");
    };
    res = 1;
  };
  CAMLreturnT(int, res);
}


CAMLprim int caml_archive_open_callback2(struct archive *ptr, struct caml_archive *data)
{
  int res = ARCHIVE_OK;

  CAMLparam0();
  CAMLlocal1(vres);

  vres = caml_callback_exn(data->open_cbk, data->client_data);
  if (caml_archive_set_error(ptr, vres))
  {
    data->close_cbk = Val_unit;
    data->client_data2 = Val_unit;
    res = ARCHIVE_FATAL;
  }
  else
  {
    data->client_data2 = vres;
    res = ARCHIVE_OK;
  };

  CAMLreturnT(int, res);
}

CAMLprim int caml_archive_open_callback(struct archive *ptr, void *client_data)
{
  int res = ARCHIVE_OK;

  caml_leave_blocking_section();
  res = caml_archive_open_callback2(ptr, client_data);
  caml_enter_blocking_section();

  return res;
};

CAMLprim ssize_t caml_archive_read_callback2(struct archive *ptr, struct caml_archive *data)
{
  ssize_t ret = -1;

  CAMLparam0();
  CAMLlocal2(res, vtup);

  res = caml_callback2_exn(data->read_cbk, data->client_data2, data->buffer);
  if (caml_archive_set_error(ptr, res))
  {
    ret = -1;
  }
  else
  {
    ret = Int_val(res);
    memcpy(data->buffer_c, String_val(data->buffer), ret);
  };

  CAMLreturnT(ssize_t, ret);
}

CAMLprim ssize_t caml_archive_read_callback(struct archive *ptr, void *client_data, const void **buffer)
{
  ssize_t res = 0;
  struct caml_archive *data = client_data;

  caml_leave_blocking_section();
  res = caml_archive_read_callback2(ptr, data);
  *buffer = data->buffer_c;
  caml_enter_blocking_section();

  return res;
};

CAMLprim la_int64_t caml_archive_skip_callback2(struct archive *ptr, struct caml_archive *data, la_int64_t request)
{
  la_int64_t ret = 0;

  CAMLparam0();
  CAMLlocal1(res);
  res = caml_callback2_exn(data->skip_cbk, data->client_data2, Val_long(request));
  if (caml_archive_set_error(ptr, res))
  {
    ret = 0;
  }
  else
  {
    ret = Long_val(res);
  };

  CAMLreturnT(la_int64_t, ret);
};

CAMLprim la_int64_t caml_archive_skip_callback(struct archive *ptr, void *client_data, la_int64_t request)
{
  la_int64_t res = 0;

  caml_leave_blocking_section();
  res = caml_archive_skip_callback2(ptr, client_data, request);
  caml_enter_blocking_section();

  return res;

};

static int seek_command_table[] = {
  [SEEK_SET]=0,
  [SEEK_CUR]=1,
  [SEEK_END]=2
};

CAMLprim la_int64_t caml_archive_seek_callback2(struct archive *ptr, struct caml_archive *data, la_int64_t offset, int whence)
{
  la_int64_t ret = 0;

  CAMLparam0();
  CAMLlocal1(res);
  res = caml_callback3_exn(data->seek_cbk, data->client_data2, Val_long(offset), Val_int(seek_command_table[whence]));
  if (caml_archive_set_error(ptr, res))
  {
    ret = 0;
  }
  else
  {
    ret = Long_val(res);
  };

  CAMLreturnT(la_int64_t, ret);
}

CAMLprim la_int64_t caml_archive_seek_callback(struct archive *ptr, void *client_data, la_int64_t offset, int whence)
{
  la_int64_t res = 0;

  caml_leave_blocking_section();
  res = caml_archive_seek_callback2(ptr, client_data, offset, whence);
  caml_enter_blocking_section();

  return res;

}

CAMLprim int caml_archive_close_callback2 (struct archive *ptr, struct caml_archive *data)
{
  int ret = ARCHIVE_OK;

  CAMLparam0();
  CAMLlocal1(res);
  if (data->close_cbk != Val_unit)
  {
    res = caml_callback_exn(data->close_cbk, data->client_data2);
    if (caml_archive_set_error(ptr, res))
    {
      ret = ARCHIVE_FATAL;
    }
  }

  CAMLreturnT(int, ret);
};

CAMLprim int caml_archive_close_callback(struct archive *ptr, void *client_data)
{
  int res = ARCHIVE_OK;
  struct caml_archive *data = client_data;

  caml_leave_blocking_section();
  res = caml_archive_close_callback2(ptr, data);

  caml_remove_global_root(&(data->open_cbk));
  caml_remove_global_root(&(data->read_cbk));
  caml_remove_global_root(&(data->skip_cbk));
  caml_remove_global_root(&(data->close_cbk));
  caml_remove_global_root(&(data->buffer));
  caml_remove_global_root(&(data->client_data));
  caml_remove_global_root(&(data->client_data2));

  caml_enter_blocking_section();

  return res;
};

CAMLprim value caml_archive_read_set_seek_callback (value vread, value vseek_cbk)
{
  ptr_archive ptr = NULL;
  CAMLparam1(vread);
  ptr = Archive_val(vread);
  ptr->seek_cbk = vseek_cbk;
  archive_read_set_seek_callback(ptr->archive, caml_archive_seek_callback);
  CAMLreturn(Val_unit);
};

CAMLprim value caml_archive_read_open2_native (
    value vread,
    value vopen_cbk,
    value vread_cbk,
    value vskip_cbk,
    value vclose_cbk,
    value vdata)
{
  struct caml_archive *read_cbk = NULL;
  ptr_archive ptr = NULL;
  int res = ARCHIVE_OK;

  CAMLparam5(vread, vopen_cbk, vread_cbk, vskip_cbk, vclose_cbk);
  CAMLxparam1(vdata);
  CAMLlocal1(vbuffer);

  vbuffer = caml_alloc_string(READ_BUFFER);

  ptr = Archive_val(vread);
  read_cbk = ptr;

  caml_register_global_root(&(read_cbk->open_cbk));
  caml_register_global_root(&(read_cbk->read_cbk));
  caml_register_global_root(&(read_cbk->skip_cbk));
  caml_register_global_root(&(read_cbk->close_cbk));
  caml_register_global_root(&(read_cbk->buffer));
  caml_register_global_root(&(read_cbk->client_data));
  caml_register_global_root(&(read_cbk->client_data2));

  read_cbk->open_cbk  = vopen_cbk;
  read_cbk->read_cbk  = vread_cbk;
  read_cbk->skip_cbk  = vskip_cbk;
  read_cbk->close_cbk = vclose_cbk;
  read_cbk->buffer    = vbuffer;
  read_cbk->client_data = vdata;
  read_cbk->client_data2 = Val_unit;

  caml_enter_blocking_section();
  res = archive_read_open2(
      ptr->archive,
      read_cbk,
      caml_archive_open_callback,
      caml_archive_read_callback,
      caml_archive_skip_callback,
      caml_archive_close_callback);
  caml_leave_blocking_section();

  caml_archive_check_error(res, ptr->archive);

  CAMLreturn(Val_unit);
};

CAMLprim value caml_archive_read_open2_bytecode (value * argv, int argn)
{
  assert(argn == 6);
  return caml_archive_read_open2_native(
      argv[0], argv[1], argv[2], argv[3], argv[4], argv[5]);
};

/*
 * Global
 */

CAMLprim value caml_archive_init (value vunit)
{
  CAMLparam1(vunit);
  caml_register_custom_operations(&caml_archive_entry_ops);
  caml_register_custom_operations(&caml_archive_ops);
  CAMLreturn(Val_unit);
};

