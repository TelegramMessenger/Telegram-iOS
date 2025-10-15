## JPEG XL GDK Pixbuf


The plugin may already have been installed when following the instructions from the
[Installing section of BUILDING.md](../../BUILDING.md#installing), in which case it should
already be in the correct place, e.g.

```/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-jxl.so```

Otherwise we can copy it manually:

```bash
sudo cp $your_build_directory/plugins/gdk-pixbuf/libpixbufloader-jxl.so /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-jxl.so
```


Then we need to update the cache, for example with:

```bash
sudo /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders --update-cache
```

In order to get thumbnails with this, first one has to add the jxl MIME type, see
[../mime/README.md](../mime/README.md).

Ensure that the thumbnailer file is installed in the correct place,
`/usr/share/thumbnailers/jxl.thumbnailer` or `/usr/local/share/thumbnailers/jxl.thumbnailer`.

The file should have been copied automatically when following the instructions
in the [Installing section of README.md](../../README.md#installing), but
otherwise it can be copied manually:

```bash
sudo cp plugins/gdk-pixbuf/jxl.thumbnailer /usr/local/share/thumbnailers/jxl.thumbnailer
```

Update the Mime database with
```bash
update-mime --local
```
or
```bash
sudo update-desktop-database
```

Then possibly delete the thumbnail cache with
```bash
rm -r ~/.cache/thumbnails
```
and restart the application displaying thumbnails, e.g. `nautilus -q` to display thumbnails.
