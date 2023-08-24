// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <string.h>

#include <string>

#include "plugins/gimp/common.h"
#include "plugins/gimp/file-jxl-load.h"
#include "plugins/gimp/file-jxl-save.h"

namespace jxl {
namespace {

constexpr char kLoadProc[] = "file-jxl-load";
constexpr char kSaveProc[] = "file-jxl-save";

void Query() {
  {
    static char run_mode_name[] = "run-mode";
    static char run_mode_description[] = "Run mode";
    static char filename_name[] = "filename";
    static char filename_description[] = "The name of the file to load";
    static char raw_filename_name[] = "raw-filename";
    static char raw_filename_description[] =
        "The name of the file, as entered by the user";
    static const GimpParamDef load_args[] = {
        {GIMP_PDB_INT32, run_mode_name, run_mode_description},
        {GIMP_PDB_STRING, filename_name, filename_description},
        {GIMP_PDB_STRING, raw_filename_name, raw_filename_description},
    };
    static char image_name[] = "image";
    static char image_description[] = "Loaded image";
    static const GimpParamDef load_return_vals[] = {
        {GIMP_PDB_IMAGE, image_name, image_description},
    };

    gimp_install_procedure(
        /*name=*/kLoadProc, /*blurb=*/"Loads JPEG XL image files",
        /*help=*/"Loads JPEG XL image files", /*author=*/"JPEG XL Project",
        /*copyright=*/"JPEG XL Project", /*date=*/"2019",
        /*menu_label=*/"JPEG XL image", /*image_types=*/nullptr,
        /*type=*/GIMP_PLUGIN, /*n_params=*/G_N_ELEMENTS(load_args),
        /*n_return_vals=*/G_N_ELEMENTS(load_return_vals), /*params=*/load_args,
        /*return_vals=*/load_return_vals);
    gimp_register_file_handler_mime(kLoadProc, "image/jxl");
    gimp_register_magic_load_handler(
        kLoadProc, "jxl", "",
        "0,string,\xFF\x0A,"
        "0,string,\\000\\000\\000\x0CJXL\\040\\015\\012\x87\\012");
  }

  {
    static char run_mode_name[] = "run-mode";
    static char run_mode_description[] = "Run mode";
    static char image_name[] = "image";
    static char image_description[] = "Input image";
    static char drawable_name[] = "drawable";
    static char drawable_description[] = "Drawable to save";
    static char filename_name[] = "filename";
    static char filename_description[] = "The name of the file to save";
    static char raw_filename_name[] = "raw-filename";
    static char raw_filename_description[] = "The name of the file to save";
    static const GimpParamDef save_args[] = {
        {GIMP_PDB_INT32, run_mode_name, run_mode_description},
        {GIMP_PDB_IMAGE, image_name, image_description},
        {GIMP_PDB_DRAWABLE, drawable_name, drawable_description},
        {GIMP_PDB_STRING, filename_name, filename_description},
        {GIMP_PDB_STRING, raw_filename_name, raw_filename_description},
    };

    gimp_install_procedure(
        /*name=*/kSaveProc, /*blurb=*/"Saves JPEG XL image files",
        /*help=*/"Saves JPEG XL image files", /*author=*/"JPEG XL Project",
        /*copyright=*/"JPEG XL Project", /*date=*/"2019",
        /*menu_label=*/"JPEG XL image", /*image_types=*/"RGB*, GRAY*",
        /*type=*/GIMP_PLUGIN, /*n_params=*/G_N_ELEMENTS(save_args),
        /*n_return_vals=*/0, /*params=*/save_args,
        /*return_vals=*/nullptr);
    gimp_register_file_handler_mime(kSaveProc, "image/jxl");
    gimp_register_save_handler(kSaveProc, "jxl", "");
  }
}

void Run(const gchar* const name, const gint nparams,
         const GimpParam* const params, gint* const nreturn_vals,
         GimpParam** const return_vals) {
  gegl_init(nullptr, nullptr);

  static GimpParam values[2];

  *nreturn_vals = 1;
  *return_vals = values;

  values[0].type = GIMP_PDB_STATUS;
  values[0].data.d_status = GIMP_PDB_EXECUTION_ERROR;

  if (strcmp(name, kLoadProc) == 0) {
    if (nparams != 3) {
      values[0].data.d_status = GIMP_PDB_CALLING_ERROR;
      return;
    }

    const gchar* const filename = params[1].data.d_string;
    gint32 image_id;
    if (!LoadJpegXlImage(filename, &image_id)) {
      values[0].data.d_status = GIMP_PDB_EXECUTION_ERROR;
      return;
    }

    *nreturn_vals = 2;
    values[0].data.d_status = GIMP_PDB_SUCCESS;
    values[1].type = GIMP_PDB_IMAGE;
    values[1].data.d_image = image_id;
  } else if (strcmp(name, kSaveProc) == 0) {
    if (nparams != 5) {
      values[0].data.d_status = GIMP_PDB_CALLING_ERROR;
      return;
    }

    gint32 image_id = params[1].data.d_image;
    gint32 drawable_id = params[2].data.d_drawable;
    const gchar* const filename = params[3].data.d_string;
    const gint32 orig_image_id = image_id;
    const GimpExportReturn export_result = gimp_export_image(
        &image_id, &drawable_id, "JPEG XL",
        static_cast<GimpExportCapabilities>(GIMP_EXPORT_CAN_HANDLE_RGB |
                                            GIMP_EXPORT_CAN_HANDLE_GRAY |
                                            GIMP_EXPORT_CAN_HANDLE_ALPHA));
    switch (export_result) {
      case GIMP_EXPORT_CANCEL:
        values[0].data.d_status = GIMP_PDB_CANCEL;
        return;
      case GIMP_EXPORT_IGNORE:
        break;
      case GIMP_EXPORT_EXPORT:
        break;
    }
    if (!SaveJpegXlImage(image_id, drawable_id, orig_image_id, filename)) {
      return;
    }
    if (image_id != orig_image_id) {
      gimp_image_delete(image_id);
    }
    values[0].data.d_status = GIMP_PDB_SUCCESS;
  }
}

}  // namespace
}  // namespace jxl

static const GimpPlugInInfo PLUG_IN_INFO = {nullptr, nullptr, &jxl::Query,
                                            &jxl::Run};

MAIN()
