// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "plugins/gimp/file-jxl-save.h"

#include <jxl/encode.h>
#include <jxl/encode_cxx.h>

#include <cmath>
#include <utility>

#include "gobject/gsignal.h"

#define PLUG_IN_BINARY "file-jxl"
#define SAVE_PROC "file-jxl-save"

#define SCALE_WIDTH 200

namespace jxl {

namespace {

#ifndef g_clear_signal_handler
// g_clear_signal_handler was added in glib 2.62
void g_clear_signal_handler(gulong* handler, gpointer instance) {
  if (handler != nullptr && *handler != 0) {
    g_signal_handler_disconnect(instance, *handler);
    *handler = 0;
  }
}
#endif  // g_clear_signal_handler

class JpegXlSaveOpts {
 public:
  float distance;
  float quality;

  bool lossless = false;
  bool is_linear = false;
  bool has_alpha = false;
  bool is_gray = false;
  bool icc_attached = false;

  bool advanced_mode = false;
  bool use_container = true;
  bool save_exif = false;
  int encoding_effort = 7;
  int faster_decoding = 0;

  std::string babl_format_str = "RGB u16";
  std::string babl_type_str = "u16";
  std::string babl_model_str = "RGB";

  JxlPixelFormat pixel_format;
  JxlBasicInfo basic_info;

  // functions
  JpegXlSaveOpts();

  bool SetDistance(float dist);
  bool SetQuality(float qual);
  bool SetDimensions(int x, int y);
  bool SetNumChannels(int channels);

  bool UpdateDistance();
  bool UpdateQuality();

  bool SetModel(bool is_linear_);

  bool UpdateBablFormat();
  bool SetBablModel(std::string model);
  bool SetBablType(std::string type);

  bool SetPrecision(int gimp_precision);

 private:
};  // class JpegXlSaveOpts

JpegXlSaveOpts jxl_save_opts;

class JpegXlSaveGui {
 public:
  bool SaveDialog();

 private:
  GtkWidget* toggle_lossless = nullptr;
  GtkAdjustment* entry_distance = nullptr;
  GtkAdjustment* entry_quality = nullptr;
  GtkAdjustment* entry_effort = nullptr;
  GtkAdjustment* entry_faster = nullptr;
  GtkWidget* frame_advanced = nullptr;
  GtkWidget* toggle_no_xyb = nullptr;
  GtkWidget* toggle_raw = nullptr;
  gulong handle_toggle_lossless = 0;
  gulong handle_entry_quality = 0;
  gulong handle_entry_distance = 0;

  static bool GuiOnChangeQuality(GtkAdjustment* adj_qual, void* this_pointer);

  static bool GuiOnChangeDistance(GtkAdjustment* adj_dist, void* this_pointer);

  static bool GuiOnChangeEffort(GtkAdjustment* adj_effort);
  static bool GuiOnChangeLossless(GtkWidget* toggle, void* this_pointer);
  static bool GuiOnChangeCodestream(GtkWidget* toggle);
  static bool GuiOnChangeNoXYB(GtkWidget* toggle);

  static bool GuiOnChangeAdvancedMode(GtkWidget* toggle, void* this_pointer);
};  // class JpegXlSaveGui

JpegXlSaveGui jxl_save_gui;

bool JpegXlSaveGui::GuiOnChangeQuality(GtkAdjustment* adj_qual,
                                       void* this_pointer) {
  JpegXlSaveGui* self = static_cast<JpegXlSaveGui*>(this_pointer);

  g_clear_signal_handler(&self->handle_entry_distance, self->entry_distance);
  g_clear_signal_handler(&self->handle_entry_quality, self->entry_quality);
  g_clear_signal_handler(&self->handle_toggle_lossless, self->toggle_lossless);

  GtkAdjustment* adj_dist = self->entry_distance;
  jxl_save_opts.SetQuality(gtk_adjustment_get_value(adj_qual));
  gtk_adjustment_set_value(adj_dist, jxl_save_opts.distance);

  self->handle_toggle_lossless = g_signal_connect(
      self->toggle_lossless, "toggled", G_CALLBACK(GuiOnChangeLossless), self);
  self->handle_entry_distance =
      g_signal_connect(self->entry_distance, "value-changed",
                       G_CALLBACK(GuiOnChangeDistance), self);
  self->handle_entry_quality =
      g_signal_connect(self->entry_quality, "value-changed",
                       G_CALLBACK(GuiOnChangeQuality), self);
  return true;
}

bool JpegXlSaveGui::GuiOnChangeDistance(GtkAdjustment* adj_dist,
                                        void* this_pointer) {
  JpegXlSaveGui* self = static_cast<JpegXlSaveGui*>(this_pointer);
  GtkAdjustment* adj_qual = self->entry_quality;

  g_clear_signal_handler(&self->handle_entry_distance, self->entry_distance);
  g_clear_signal_handler(&self->handle_entry_quality, self->entry_quality);
  g_clear_signal_handler(&self->handle_toggle_lossless, self->toggle_lossless);

  jxl_save_opts.SetDistance(gtk_adjustment_get_value(adj_dist));
  gtk_adjustment_set_value(adj_qual, jxl_save_opts.quality);

  if (!(jxl_save_opts.distance < 0.001)) {
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->toggle_lossless),
                                 false);
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->toggle_no_xyb), false);
  }

  self->handle_toggle_lossless = g_signal_connect(
      self->toggle_lossless, "toggled", G_CALLBACK(GuiOnChangeLossless), self);
  self->handle_entry_distance =
      g_signal_connect(self->entry_distance, "value-changed",
                       G_CALLBACK(GuiOnChangeDistance), self);
  self->handle_entry_quality =
      g_signal_connect(self->entry_quality, "value-changed",
                       G_CALLBACK(GuiOnChangeQuality), self);
  return true;
}

bool JpegXlSaveGui::GuiOnChangeEffort(GtkAdjustment* adj_effort) {
  float new_effort = 10 - gtk_adjustment_get_value(adj_effort);
  jxl_save_opts.encoding_effort = new_effort;
  return true;
}

bool JpegXlSaveGui::GuiOnChangeLossless(GtkWidget* toggle, void* this_pointer) {
  JpegXlSaveGui* self = static_cast<JpegXlSaveGui*>(this_pointer);
  GtkAdjustment* adj_distance = self->entry_distance;
  GtkAdjustment* adj_quality = self->entry_quality;
  GtkAdjustment* adj_effort = self->entry_effort;

  jxl_save_opts.lossless =
      gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(toggle));

  g_clear_signal_handler(&self->handle_entry_distance, self->entry_distance);
  g_clear_signal_handler(&self->handle_entry_quality, self->entry_quality);
  g_clear_signal_handler(&self->handle_toggle_lossless, self->toggle_lossless);

  if (jxl_save_opts.lossless) {
    gtk_adjustment_set_value(adj_quality, 100.0);
    gtk_adjustment_set_value(adj_distance, 0.0);
    jxl_save_opts.distance = 0;
    jxl_save_opts.UpdateQuality();
    gtk_adjustment_set_value(adj_effort, 7);
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->toggle_no_xyb), true);
  } else {
    gtk_adjustment_set_value(adj_quality, 90.0);
    gtk_adjustment_set_value(adj_distance, 1.0);
    jxl_save_opts.distance = 1.0;
    jxl_save_opts.UpdateQuality();
    gtk_adjustment_set_value(adj_effort, 3);
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->toggle_no_xyb), false);
  }
  self->handle_toggle_lossless = g_signal_connect(
      self->toggle_lossless, "toggled", G_CALLBACK(GuiOnChangeLossless), self);
  self->handle_entry_distance =
      g_signal_connect(self->entry_distance, "value-changed",
                       G_CALLBACK(GuiOnChangeDistance), self);
  self->handle_entry_quality =
      g_signal_connect(self->entry_quality, "value-changed",
                       G_CALLBACK(GuiOnChangeQuality), self);
  return true;
}

bool JpegXlSaveGui::GuiOnChangeCodestream(GtkWidget* toggle) {
  jxl_save_opts.use_container =
      !gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(toggle));
  return true;
}

bool JpegXlSaveGui::GuiOnChangeNoXYB(GtkWidget* toggle) {
  jxl_save_opts.basic_info.uses_original_profile =
      gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(toggle));
  return true;
}

bool JpegXlSaveGui::GuiOnChangeAdvancedMode(GtkWidget* toggle,
                                            void* this_pointer) {
  JpegXlSaveGui* self = static_cast<JpegXlSaveGui*>(this_pointer);
  jxl_save_opts.advanced_mode =
      gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(toggle));

  gtk_widget_set_sensitive(self->frame_advanced, jxl_save_opts.advanced_mode);

  if (!jxl_save_opts.advanced_mode) {
    jxl_save_opts.basic_info.uses_original_profile = false;
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->toggle_no_xyb), false);

    jxl_save_opts.use_container = true;
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->toggle_raw), false);

    jxl_save_opts.faster_decoding = 0;
    gtk_adjustment_set_value(GTK_ADJUSTMENT(self->entry_faster), 0);
  }
  return true;
}

bool JpegXlSaveGui::SaveDialog() {
  gboolean run;
  GtkWidget* dialog;
  GtkWidget* content_area;
  GtkWidget* main_vbox;
  GtkWidget* frame;
  GtkWidget* toggle;
  GtkWidget* table;
  GtkWidget* vbox;
  GtkWidget* separator;

  // initialize export dialog
  gimp_ui_init(PLUG_IN_BINARY, true);
  dialog = gimp_export_dialog_new("JPEG XL", PLUG_IN_BINARY, SAVE_PROC);

  gtk_window_set_resizable(GTK_WINDOW(dialog), false);
  content_area = gimp_export_dialog_get_content_area(dialog);

  main_vbox = gtk_vbox_new(false, 6);
  gtk_container_set_border_width(GTK_CONTAINER(main_vbox), 6);
  gtk_box_pack_start(GTK_BOX(content_area), main_vbox, true, true, 0);
  gtk_widget_show(main_vbox);

  // Standard Settings Frame
  frame = gtk_frame_new(nullptr);
  gtk_frame_set_shadow_type(GTK_FRAME(frame), GTK_SHADOW_ETCHED_IN);
  gtk_box_pack_start(GTK_BOX(main_vbox), frame, false, false, 0);
  gtk_widget_show(frame);

  vbox = gtk_vbox_new(false, 6);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 6);
  gtk_container_add(GTK_CONTAINER(frame), vbox);
  gtk_widget_show(vbox);

  // Layout Table
  table = gtk_table_new(20, 3, false);
  gtk_table_set_col_spacings(GTK_TABLE(table), 6);
  gtk_box_pack_start(GTK_BOX(vbox), table, false, false, 0);
  gtk_widget_show(table);

  // Distance Slider
  static gchar distance_help[] =
      "Butteraugli distance target.  Suggested values:"
      "\n\td\u00A0=\u00A00.3\tExcellent"
      "\n\td\u00A0=\u00A01\tVery Good"
      "\n\td\u00A0=\u00A02\tGood"
      "\n\td\u00A0=\u00A03\tFair"
      "\n\td\u00A0=\u00A06\tPoor";

  entry_distance = (GtkAdjustment*)gimp_scale_entry_new(
      GTK_TABLE(table), 0, 0, "Distance", SCALE_WIDTH, 0,
      jxl_save_opts.distance, 0.0, 15.0, 0.001, 1.0, 3, true, 0.0, 0.0,
      distance_help, SAVE_PROC);
  gimp_scale_entry_set_logarithmic((GtkObject*)entry_distance, true);

  // Quality Slider
  static gchar quality_help[] =
      "JPEG-style Quality is remapped to distance.  "
      "Values roughly match libjpeg quality settings.";
  entry_quality = (GtkAdjustment*)gimp_scale_entry_new(
      GTK_TABLE(table), 0, 1, "Quality", SCALE_WIDTH, 0, jxl_save_opts.quality,
      8.26, 100.0, 1.0, 10.0, 2, true, 0.0, 0.0, quality_help, SAVE_PROC);

  // Distance and Quality Signals
  handle_entry_distance = g_signal_connect(
      entry_distance, "value-changed", G_CALLBACK(GuiOnChangeDistance), this);
  handle_entry_quality = g_signal_connect(entry_quality, "value-changed",
                                          G_CALLBACK(GuiOnChangeQuality), this);

  // ----------
  separator = gtk_vseparator_new();
  gtk_table_attach(GTK_TABLE(table), separator, 0, 2, 2, 3, GTK_EXPAND,
                   GTK_EXPAND, 9, 9);
  gtk_widget_show(separator);

  // Encoding Effort / Speed
  static gchar effort_help[] =
      "Adjust encoding speed.  Higher values are faster because "
      "the encoder uses less effort to hit distance targets.  "
      "As\u00A0a\u00A0result, image quality may be decreased.  "
      "Default\u00A0=\u00A03.";
  entry_effort = (GtkAdjustment*)gimp_scale_entry_new(
      GTK_TABLE(table), 0, 3, "Speed", SCALE_WIDTH, 0,
      10 - jxl_save_opts.encoding_effort, 1, 9, 1, 2, 0, true, 0.0, 0.0,
      effort_help, SAVE_PROC);

  // effort signal
  g_signal_connect(entry_effort, "value-changed", G_CALLBACK(GuiOnChangeEffort),
                   nullptr);

  // ----------
  separator = gtk_vseparator_new();
  gtk_table_attach(GTK_TABLE(table), separator, 0, 2, 4, 5, GTK_EXPAND,
                   GTK_EXPAND, 9, 9);
  gtk_widget_show(separator);

  // Lossless Mode Convenience Checkbox
  static gchar lossless_help[] =
      "Compress using modular lossless mode.  "
      "Speed\u00A0is adjusted to improve performance.";
  toggle_lossless = gtk_check_button_new_with_label("Lossless Mode");
  gimp_help_set_help_data(toggle_lossless, lossless_help, nullptr);
  gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(toggle_lossless),
                               jxl_save_opts.lossless);
  gtk_table_attach_defaults(GTK_TABLE(table), toggle_lossless, 0, 2, 5, 6);
  gtk_widget_show(toggle_lossless);

  // lossless signal
  handle_toggle_lossless = g_signal_connect(
      toggle_lossless, "toggled", G_CALLBACK(GuiOnChangeLossless), this);

  // ----------
  separator = gtk_vseparator_new();
  gtk_box_pack_start(GTK_BOX(main_vbox), separator, false, false, 1);
  gtk_widget_show(separator);

  // Advanced Settings Frame
  frame_advanced = gtk_frame_new("Advanced Settings");
  gimp_help_set_help_data(frame_advanced,
                          "Some advanced settings may produce malformed files.",
                          nullptr);
  gtk_frame_set_shadow_type(GTK_FRAME(frame_advanced), GTK_SHADOW_ETCHED_IN);
  gtk_box_pack_start(GTK_BOX(main_vbox), frame_advanced, true, true, 0);
  gtk_widget_show(frame_advanced);

  gtk_widget_set_sensitive(frame_advanced, false);

  vbox = gtk_vbox_new(false, 6);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 6);
  gtk_container_add(GTK_CONTAINER(frame_advanced), vbox);
  gtk_widget_show(vbox);

  // uses_original_profile
  static gchar uses_original_profile_help[] =
      "Prevents conversion to the XYB colorspace.  "
      "File sizes are approximately doubled.";
  toggle_no_xyb = gtk_check_button_new_with_label("Do not use XYB colorspace");
  gimp_help_set_help_data(toggle_no_xyb, uses_original_profile_help, nullptr);
  gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(toggle_no_xyb),
                               jxl_save_opts.basic_info.uses_original_profile);
  gtk_box_pack_start(GTK_BOX(vbox), toggle_no_xyb, false, false, 0);
  gtk_widget_show(toggle_no_xyb);

  g_signal_connect(toggle_no_xyb, "toggled", G_CALLBACK(GuiOnChangeNoXYB),
                   nullptr);

  // save raw codestream
  static gchar codestream_help[] =
      "Save the raw codestream, without a container.  "
      "The container is required for metadata and some other features.";
  toggle_raw = gtk_check_button_new_with_label("Save Raw Codestream");
  gimp_help_set_help_data(toggle_raw, codestream_help, nullptr);
  gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(toggle_raw),
                               !jxl_save_opts.use_container);
  gtk_box_pack_start(GTK_BOX(vbox), toggle_raw, false, false, 0);
  gtk_widget_show(toggle_raw);

  g_signal_connect(toggle_raw, "toggled", G_CALLBACK(GuiOnChangeCodestream),
                   nullptr);

  // ----------
  separator = gtk_vseparator_new();
  gtk_box_pack_start(GTK_BOX(vbox), separator, false, false, 1);
  gtk_widget_show(separator);

  // Faster Decoding / Decoding Speed
  static gchar faster_help[] =
      "Improve decoding speed at the expense of quality.  "
      "Default\u00A0=\u00A00.";
  table = gtk_table_new(1, 3, false);
  gtk_table_set_col_spacings(GTK_TABLE(table), 6);
  gtk_container_add(GTK_CONTAINER(vbox), table);
  gtk_widget_show(table);

  entry_faster = (GtkAdjustment*)gimp_scale_entry_new(
      GTK_TABLE(table), 0, 0, "Faster Decoding", SCALE_WIDTH, 0,
      jxl_save_opts.faster_decoding, 0, 4, 1, 1, 0, true, 0.0, 0.0, faster_help,
      SAVE_PROC);

  // Faster Decoding Signals
  g_signal_connect(entry_faster, "value-changed",
                   G_CALLBACK(gimp_int_adjustment_update),
                   &jxl_save_opts.faster_decoding);

  // Enable Advanced Settings
  frame = gtk_frame_new(nullptr);
  gtk_frame_set_shadow_type(GTK_FRAME(frame), GTK_SHADOW_NONE);
  gtk_box_pack_start(GTK_BOX(main_vbox), frame, true, true, 0);
  gtk_widget_show(frame);

  vbox = gtk_vbox_new(false, 6);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 6);
  gtk_container_add(GTK_CONTAINER(frame), vbox);
  gtk_widget_show(vbox);

  static gchar advanced_help[] =
      "Some advanced settings may produce malformed files.";
  toggle = gtk_check_button_new_with_label("Enable Advanced Settings");
  gimp_help_set_help_data(toggle, advanced_help, nullptr);
  gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(toggle),
                               jxl_save_opts.advanced_mode);
  gtk_box_pack_start(GTK_BOX(vbox), toggle, false, false, 0);
  gtk_widget_show(toggle);

  g_signal_connect(toggle, "toggled", G_CALLBACK(GuiOnChangeAdvancedMode),
                   this);

  // show dialog
  gtk_widget_show(dialog);

  GtkAllocation allocation;
  gtk_widget_get_allocation(dialog, &allocation);

  int height = allocation.height;
  gtk_widget_set_size_request(dialog, height * 1.5, height);

  run = (gimp_dialog_run(GIMP_DIALOG(dialog)) == GTK_RESPONSE_OK);
  gtk_widget_destroy(dialog);

  return run;
}  // JpegXlSaveGui::SaveDialog

JpegXlSaveOpts::JpegXlSaveOpts() {
  SetDistance(1.0);

  pixel_format.num_channels = 4;
  pixel_format.data_type = JXL_TYPE_FLOAT;
  pixel_format.endianness = JXL_NATIVE_ENDIAN;
  pixel_format.align = 0;

  JxlEncoderInitBasicInfo(&basic_info);
  return;
}  // JpegXlSaveOpts constructor

bool JpegXlSaveOpts::SetModel(bool is_linear_) {
  int channels;
  std::string model;

  if (is_gray) {
    channels = 1;
    if (is_linear_) {
      model = "Y";
    } else {
      model = "Y'";
    }
  } else {
    channels = 3;
    if (is_linear_) {
      model = "RGB";
    } else {
      model = "R'G'B'";
    }
  }
  if (has_alpha) {
    SetBablModel(model + "A");
    SetNumChannels(channels + 1);
  } else {
    SetBablModel(model);
    SetNumChannels(channels);
  }
  return true;
}  // JpegXlSaveOpts::SetModel

bool JpegXlSaveOpts::SetDistance(float dist) {
  distance = dist;
  return UpdateQuality();
}

bool JpegXlSaveOpts::SetQuality(float qual) {
  quality = qual;
  return UpdateDistance();
}

bool JpegXlSaveOpts::UpdateQuality() {
  float qual;

  if (distance < 0.1) {
    qual = 100;
  } else if (distance > 6.4) {
    qual = -5.0 / 53.0 * sqrt(6360.0 * distance - 39975.0) + 1725.0 / 53.0;
    lossless = false;
  } else {
    qual = 100 - (distance - 0.1) / 0.09;
    lossless = false;
  }

  if (qual < 0) {
    quality = 0.0;
  } else if (qual >= 100) {
    quality = 100.0;
  } else {
    quality = qual;
  }

  return true;
}

bool JpegXlSaveOpts::UpdateDistance() {
  float dist;
  if (quality >= 30) {
    dist = 0.1 + (100 - quality) * 0.09;
  } else {
    dist = 53.0 / 3000.0 * quality * quality - 23.0 / 20.0 * quality + 25.0;
  }

  if (dist > 25) {
    distance = 25;
  } else {
    distance = dist;
  }
  return true;
}

bool JpegXlSaveOpts::SetDimensions(int x, int y) {
  basic_info.xsize = x;
  basic_info.ysize = y;
  return true;
}

bool JpegXlSaveOpts::SetNumChannels(int channels) {
  switch (channels) {
    case 1:
      pixel_format.num_channels = 1;
      basic_info.num_color_channels = 1;
      basic_info.num_extra_channels = 0;
      basic_info.alpha_bits = 0;
      basic_info.alpha_exponent_bits = 0;
      break;
    case 2:
      pixel_format.num_channels = 2;
      basic_info.num_color_channels = 1;
      basic_info.num_extra_channels = 1;
      basic_info.alpha_bits = int(std::fmin(16, basic_info.bits_per_sample));
      basic_info.alpha_exponent_bits = 0;
      break;
    case 3:
      pixel_format.num_channels = 3;
      basic_info.num_color_channels = 3;
      basic_info.num_extra_channels = 0;
      basic_info.alpha_bits = 0;
      basic_info.alpha_exponent_bits = 0;
      break;
    case 4:
      pixel_format.num_channels = 4;
      basic_info.num_color_channels = 3;
      basic_info.num_extra_channels = 1;
      basic_info.alpha_bits = int(std::fmin(16, basic_info.bits_per_sample));
      basic_info.alpha_exponent_bits = 0;
      break;
    default:
      SetNumChannels(3);
  }  // switch
  return true;
}  // JpegXlSaveOpts::SetNumChannels

bool JpegXlSaveOpts::UpdateBablFormat() {
  babl_format_str = babl_model_str + " " + babl_type_str;
  return true;
}

bool JpegXlSaveOpts::SetBablModel(std::string model) {
  babl_model_str = std::move(model);
  return UpdateBablFormat();
}

bool JpegXlSaveOpts::SetBablType(std::string type) {
  babl_type_str = std::move(type);
  return UpdateBablFormat();
}

bool JpegXlSaveOpts::SetPrecision(int gimp_precision) {
  switch (gimp_precision) {
    case GIMP_PRECISION_HALF_GAMMA:
    case GIMP_PRECISION_HALF_LINEAR:
      basic_info.bits_per_sample = 16;
      basic_info.exponent_bits_per_sample = 5;
      break;

    // UINT32 not supported by encoder; using FLOAT instead
    case GIMP_PRECISION_U32_GAMMA:
    case GIMP_PRECISION_U32_LINEAR:
    case GIMP_PRECISION_FLOAT_GAMMA:
    case GIMP_PRECISION_FLOAT_LINEAR:
      basic_info.bits_per_sample = 32;
      basic_info.exponent_bits_per_sample = 8;
      break;

    case GIMP_PRECISION_U16_GAMMA:
    case GIMP_PRECISION_U16_LINEAR:
      basic_info.bits_per_sample = 16;
      basic_info.exponent_bits_per_sample = 0;
      break;

    default:
    case GIMP_PRECISION_U8_LINEAR:
    case GIMP_PRECISION_U8_GAMMA:
      basic_info.bits_per_sample = 8;
      basic_info.exponent_bits_per_sample = 0;
      break;
  }
  return true;
}  // JpegXlSaveOpts::SetPrecision

}  // namespace

bool SaveJpegXlImage(const gint32 image_id, const gint32 drawable_id,
                     const gint32 orig_image_id, const gchar* const filename) {
  if (!jxl_save_gui.SaveDialog()) {
    return true;
  }

  gint32 nlayers;
  gint32* layers;
  gint32 duplicate = gimp_image_duplicate(image_id);

  JpegXlGimpProgress gimp_save_progress(
      ("Saving JPEG XL file:" + std::string(filename)).c_str());
  gimp_save_progress.update();

  // try to get ICC color profile...
  std::vector<uint8_t> icc;

  GimpColorProfile* profile = gimp_image_get_effective_color_profile(image_id);
  jxl_save_opts.is_gray = gimp_color_profile_is_gray(profile);
  jxl_save_opts.is_linear = gimp_color_profile_is_linear(profile);

  profile = gimp_image_get_color_profile(image_id);
  if (profile) {
    g_printerr(SAVE_PROC " Info: Extracting ICC Profile...\n");
    gsize icc_size;
    const guint8* const icc_bytes =
        gimp_color_profile_get_icc_profile(profile, &icc_size);

    icc.assign(icc_bytes, icc_bytes + icc_size);
  } else {
    g_printerr(SAVE_PROC " Info: No ICC profile.  Exporting image anyway.\n");
  }

  gimp_save_progress.update();

  jxl_save_opts.SetDimensions(gimp_image_width(image_id),
                              gimp_image_height(image_id));

  jxl_save_opts.SetPrecision(gimp_image_get_precision(image_id));
  layers = gimp_image_get_layers(duplicate, &nlayers);

  for (int i = 0; i < nlayers; i++) {
    if (gimp_drawable_has_alpha(layers[i])) {
      jxl_save_opts.has_alpha = true;
      break;
    }
  }

  gimp_save_progress.update();

  // layers need to match image size, for now
  for (int i = 0; i < nlayers; i++) {
    gimp_layer_resize_to_image_size(layers[i]);
  }

  // treat layers as animation frames, for now
  if (nlayers > 1) {
    jxl_save_opts.basic_info.have_animation = true;
    jxl_save_opts.basic_info.animation.tps_numerator = 100;
  }

  gimp_save_progress.update();

  // multi-threaded parallel runner.
  auto runner = JxlResizableParallelRunnerMake(nullptr);

  JxlResizableParallelRunnerSetThreads(
      runner.get(),
      JxlResizableParallelRunnerSuggestThreads(jxl_save_opts.basic_info.xsize,
                                               jxl_save_opts.basic_info.ysize));

  auto enc = JxlEncoderMake(/*memory_manager=*/nullptr);
  JxlEncoderUseContainer(enc.get(), jxl_save_opts.use_container);

  if (JXL_ENC_SUCCESS != JxlEncoderSetParallelRunner(enc.get(),
                                                     JxlResizableParallelRunner,
                                                     runner.get())) {
    g_printerr(SAVE_PROC " Error: JxlEncoderSetParallelRunner failed\n");
    return false;
  }

  // this sets some basic_info properties
  jxl_save_opts.SetModel(jxl_save_opts.is_linear);

  if (JXL_ENC_SUCCESS !=
      JxlEncoderSetBasicInfo(enc.get(), &jxl_save_opts.basic_info)) {
    g_printerr(SAVE_PROC " Error: JxlEncoderSetBasicInfo failed\n");
    return false;
  }

  // try to use ICC profile
  if (!icc.empty() && !jxl_save_opts.is_gray) {
    if (JXL_ENC_SUCCESS ==
        JxlEncoderSetICCProfile(enc.get(), icc.data(), icc.size())) {
      jxl_save_opts.icc_attached = true;
    } else {
      g_printerr(SAVE_PROC " Warning: JxlEncoderSetICCProfile failed.\n");
      jxl_save_opts.basic_info.uses_original_profile = false;
      jxl_save_opts.lossless = false;
    }
  } else {
    g_printerr(SAVE_PROC " Warning: Using internal profile.\n");
    jxl_save_opts.basic_info.uses_original_profile = false;
    jxl_save_opts.lossless = false;
  }

  // set up internal color profile
  JxlColorEncoding color_encoding = {};

  if (jxl_save_opts.is_linear) {
    JxlColorEncodingSetToLinearSRGB(&color_encoding, jxl_save_opts.is_gray);
  } else {
    JxlColorEncodingSetToSRGB(&color_encoding, jxl_save_opts.is_gray);
  }

  if (JXL_ENC_SUCCESS !=
      JxlEncoderSetColorEncoding(enc.get(), &color_encoding)) {
    g_printerr(SAVE_PROC " Warning: JxlEncoderSetColorEncoding failed\n");
  }

  // set encoder options
  JxlEncoderFrameSettings* frame_settings;
  frame_settings = JxlEncoderFrameSettingsCreate(enc.get(), nullptr);

  JxlEncoderFrameSettingsSetOption(frame_settings, JXL_ENC_FRAME_SETTING_EFFORT,
                                   jxl_save_opts.encoding_effort);
  JxlEncoderFrameSettingsSetOption(frame_settings,
                                   JXL_ENC_FRAME_SETTING_DECODING_SPEED,
                                   jxl_save_opts.faster_decoding);

  // lossless mode
  if (jxl_save_opts.lossless || jxl_save_opts.distance < 0.01) {
    if (jxl_save_opts.basic_info.exponent_bits_per_sample > 0) {
      // lossless mode doesn't work well with floating point
      jxl_save_opts.distance = 0.01;
      jxl_save_opts.lossless = false;
      JxlEncoderSetFrameLossless(frame_settings, false);
      JxlEncoderSetFrameDistance(frame_settings, 0.01);
    } else {
      JxlEncoderSetFrameDistance(frame_settings, 0);
      JxlEncoderSetFrameLossless(frame_settings, true);
    }
  } else {
    jxl_save_opts.lossless = false;
    JxlEncoderSetFrameLossless(frame_settings, false);
    JxlEncoderSetFrameDistance(frame_settings, jxl_save_opts.distance);
  }

  // convert precision and colorspace
  if (jxl_save_opts.is_linear &&
      jxl_save_opts.basic_info.bits_per_sample < 32) {
    gimp_image_convert_precision(duplicate, GIMP_PRECISION_FLOAT_LINEAR);
  } else {
    gimp_image_convert_precision(duplicate, GIMP_PRECISION_FLOAT_GAMMA);
  }

  // process layers and compress into JXL
  size_t buffer_size =
      jxl_save_opts.basic_info.xsize * jxl_save_opts.basic_info.ysize *
      jxl_save_opts.pixel_format.num_channels * 4;  // bytes per sample

  for (int i = nlayers - 1; i >= 0; i--) {
    gimp_save_progress.update();

    // copy image into buffer...
    gpointer pixels_buffer_1;
    gpointer pixels_buffer_2;
    pixels_buffer_1 = g_malloc(buffer_size);
    pixels_buffer_2 = g_malloc(buffer_size);

    gimp_layer_resize_to_image_size(layers[i]);

    GeglBuffer* buffer = gimp_drawable_get_buffer(layers[i]);

    // using gegl_buffer_set_format to get the format because
    // gegl_buffer_get_format doesn't always get the original format
    const Babl* native_format = gegl_buffer_set_format(buffer, nullptr);

    gegl_buffer_get(buffer,
                    GEGL_RECTANGLE(0, 0, jxl_save_opts.basic_info.xsize,
                                   jxl_save_opts.basic_info.ysize),
                    1.0, native_format, pixels_buffer_1, GEGL_AUTO_ROWSTRIDE,
                    GEGL_ABYSS_NONE);
    g_clear_object(&buffer);

    // use babl to fix gamma mismatch issues
    jxl_save_opts.SetModel(jxl_save_opts.is_linear);
    jxl_save_opts.pixel_format.data_type = JXL_TYPE_FLOAT;
    jxl_save_opts.SetBablType("float");
    const Babl* destination_format =
        babl_format(jxl_save_opts.babl_format_str.c_str());

    babl_process(
        babl_fish(native_format, destination_format), pixels_buffer_1,
        pixels_buffer_2,
        jxl_save_opts.basic_info.xsize * jxl_save_opts.basic_info.ysize);

    gimp_save_progress.update();

    // send layer to encoder
    if (JXL_ENC_SUCCESS !=
        JxlEncoderAddImageFrame(frame_settings, &jxl_save_opts.pixel_format,
                                pixels_buffer_2, buffer_size)) {
      g_printerr(SAVE_PROC " Error: JxlEncoderAddImageFrame failed\n");
      return false;
    }
  }

  JxlEncoderCloseInput(enc.get());

  // get data from encoder
  std::vector<uint8_t> compressed;
  compressed.resize(262144);
  uint8_t* next_out = compressed.data();
  size_t avail_out = compressed.size();

  JxlEncoderStatus process_result = JXL_ENC_NEED_MORE_OUTPUT;
  while (process_result == JXL_ENC_NEED_MORE_OUTPUT) {
    gimp_save_progress.update();

    process_result = JxlEncoderProcessOutput(enc.get(), &next_out, &avail_out);
    if (process_result == JXL_ENC_NEED_MORE_OUTPUT) {
      size_t offset = next_out - compressed.data();
      compressed.resize(compressed.size() + 262144);
      next_out = compressed.data() + offset;
      avail_out = compressed.size() - offset;
    }
  }
  compressed.resize(next_out - compressed.data());

  if (JXL_ENC_SUCCESS != process_result) {
    g_printerr(SAVE_PROC " Error: JxlEncoderProcessOutput failed\n");
    return false;
  }

  // write file
  std::ofstream outstream(filename, std::ios::out | std::ios::binary);
  copy(compressed.begin(), compressed.end(),
       std::ostream_iterator<uint8_t>(outstream));

  gimp_save_progress.finished();
  return true;
}  // SaveJpegXlImage()

}  // namespace jxl
