## :warning: Not needed anymore

As `image/jxl` is now supported by [shared-mine-info 2.2](https://gitlab.freedesktop.org/xdg/shared-mime-info/-/releases/2.2), it should not be necessary anymore to install this plugin.

You can test if your system correctly understand the MIME type of JPEG XL image by obtaining a JPEG XL image, e.g. with
```bash
wget https://raw.githubusercontent.com/libjxl/conformance/master/testcases/bicycles/input.jxl
```
and with that sample JPEG XL file `input.jxl` (or any other valid JPEG XL file), run any of the following commands:
```bash
xdg-mime query filetype input.jxl
file --mime-type input.jxl
mimetype input.jxl
```
If the output contains `image/jxl` you are all set!


## JPEG XL MIME type

If not already installed by the [Installing section of BUILDING.md](../../BUILDING.md#installing), then it can be done manually:

### Install
```bash
sudo xdg-mime install --novendor image-jxl.xml
```

Then run:
```
update-mime --local
```


### Uninstall
```bash
sudo xdg-mime uninstall image-jxl.xml
```

