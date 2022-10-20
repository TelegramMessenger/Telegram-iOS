# Makefile

include config.mak

vpath %.c $(SRCPATH)
vpath %.h $(SRCPATH)
vpath %.S $(SRCPATH)
vpath %.asm $(SRCPATH)
vpath %.rc $(SRCPATH)
vpath %.manifest $(SRCPATH)

CFLAGS += $(CFLAGSPROF)
LDFLAGS += $(LDFLAGSPROF)

GENERATED =

all: default
default:

SRCS = common/osdep.c common/base.c common/cpu.c common/tables.c \
       encoder/api.c

SRCS_X = common/mc.c common/predict.c common/pixel.c common/macroblock.c \
         common/frame.c common/dct.c common/cabac.c \
         common/common.c common/rectangle.c \
         common/set.c common/quant.c common/deblock.c common/vlc.c \
         common/mvpred.c common/bitstream.c \
         encoder/analyse.c encoder/me.c encoder/ratecontrol.c \
         encoder/set.c encoder/macroblock.c encoder/cabac.c \
         encoder/cavlc.c encoder/encoder.c encoder/lookahead.c

SRCS_8 =

SRCCLI = x264.c autocomplete.c input/input.c input/timecode.c input/raw.c \
         input/y4m.c output/raw.c output/matroska.c output/matroska_ebml.c \
         output/flv.c output/flv_bytestream.c filters/filters.c \
         filters/video/video.c filters/video/source.c filters/video/internal.c \
         filters/video/resize.c filters/video/fix_vfr_pts.c \
         filters/video/select_every.c filters/video/crop.c

SRCCLI_X = filters/video/cache.c filters/video/depth.c

SRCSO =

SRCCHK_X = tools/checkasm.c

SRCEXAMPLE = example.c

OBJS =
OBJASM =
OBJSO =
OBJCLI =
OBJCHK =
OBJCHK_8 =
OBJCHK_10 =
OBJEXAMPLE =

CONFIG := $(shell cat config.h)

# Optional module sources
ifneq ($(findstring HAVE_AVS 1, $(CONFIG)),)
SRCCLI += input/avs.c
endif

ifneq ($(findstring HAVE_THREAD 1, $(CONFIG)),)
SRCS_X   += common/threadpool.c
SRCCLI_X += input/thread.c
endif

ifneq ($(findstring HAVE_WIN32THREAD 1, $(CONFIG)),)
SRCS += common/win32thread.c
endif

ifneq ($(findstring HAVE_LAVF 1, $(CONFIG)),)
SRCCLI += input/lavf.c
endif

ifneq ($(findstring HAVE_FFMS 1, $(CONFIG)),)
SRCCLI += input/ffms.c
endif

ifneq ($(findstring HAVE_GPAC 1, $(CONFIG)),)
SRCCLI += output/mp4.c
endif

ifneq ($(findstring HAVE_LSMASH 1, $(CONFIG)),)
SRCCLI += output/mp4_lsmash.c
endif

ifneq ($(AS),)

# MMX/SSE optims
SRCASM_X =
ifeq ($(SYS_ARCH),X86)
ARCH_X86 = yes
SRCASM_X += common/x86/dct-32.asm \
            common/x86/pixel-32.asm
endif
ifeq ($(SYS_ARCH),X86_64)
ARCH_X86 = yes
SRCASM_X += common/x86/dct-64.asm \
            common/x86/trellis-64.asm
endif

ifdef ARCH_X86
SRCASM_X += common/x86/bitstream-a.asm \
            common/x86/const-a.asm \
            common/x86/cabac-a.asm \
            common/x86/dct-a.asm \
            common/x86/deblock-a.asm \
            common/x86/mc-a.asm \
            common/x86/mc-a2.asm \
            common/x86/pixel-a.asm \
            common/x86/predict-a.asm \
            common/x86/quant-a.asm
SRCS_X   += common/x86/mc-c.c \
            common/x86/predict-c.c

OBJASM += common/x86/cpu-a.o
ifneq ($(findstring HAVE_BITDEPTH8 1, $(CONFIG)),)
OBJASM += $(SRCASM_X:%.asm=%-8.o) common/x86/sad-a-8.o
endif
ifneq ($(findstring HAVE_BITDEPTH10 1, $(CONFIG)),)
OBJASM += $(SRCASM_X:%.asm=%-10.o) common/x86/sad16-a-10.o
endif

OBJCHK += tools/checkasm-a.o
endif

# AltiVec optims
ifeq ($(SYS_ARCH),PPC)
SRCS_X += common/ppc/dct.c \
          common/ppc/deblock.c \
          common/ppc/mc.c \
          common/ppc/pixel.c \
          common/ppc/predict.c \
          common/ppc/quant.c
endif

# NEON optims
ifeq ($(SYS_ARCH),ARM)
SRCASM_X  = common/arm/bitstream-a.S \
            common/arm/dct-a.S \
            common/arm/deblock-a.S \
            common/arm/mc-a.S \
            common/arm/pixel-a.S \
            common/arm/predict-a.S \
            common/arm/quant-a.S
SRCS_X   += common/arm/mc-c.c \
            common/arm/predict-c.c

OBJASM += common/arm/cpu-a.o
ifneq ($(findstring HAVE_BITDEPTH8 1, $(CONFIG)),)
OBJASM += $(SRCASM_X:%.S=%-8.o)
endif
ifneq ($(findstring HAVE_BITDEPTH10 1, $(CONFIG)),)
OBJASM += $(SRCASM_X:%.S=%-10.o)
endif

OBJCHK += tools/checkasm-arm.o
endif

# AArch64 NEON optims
ifeq ($(SYS_ARCH),AARCH64)
SRCASM_X  = common/aarch64/bitstream-a.S \
            common/aarch64/cabac-a.S \
            common/aarch64/dct-a.S \
            common/aarch64/deblock-a.S \
            common/aarch64/mc-a.S \
            common/aarch64/pixel-a.S \
            common/aarch64/predict-a.S \
            common/aarch64/quant-a.S
SRCS_X   += common/aarch64/asm-offsets.c \
            common/aarch64/mc-c.c \
            common/aarch64/predict-c.c

OBJASM +=
ifneq ($(findstring HAVE_BITDEPTH8 1, $(CONFIG)),)
OBJASM += $(SRCASM_X:%.S=%-8.o)
endif
ifneq ($(findstring HAVE_BITDEPTH10 1, $(CONFIG)),)
OBJASM += $(SRCASM_X:%.S=%-10.o)
endif

OBJCHK += tools/checkasm-aarch64.o
endif

# MSA optims
ifeq ($(SYS_ARCH),MIPS)
ifneq ($(findstring HAVE_MSA 1, $(CONFIG)),)
SRCS_X += common/mips/dct-c.c \
          common/mips/deblock-c.c \
          common/mips/mc-c.c \
          common/mips/pixel-c.c \
          common/mips/predict-c.c \
          common/mips/quant-c.c
endif
endif

endif

ifneq ($(HAVE_GETOPT_LONG),1)
SRCCLI += extras/getopt.c
endif

ifeq ($(SYS),WINDOWS)
OBJCLI += $(if $(RC), x264res.o)
ifneq ($(SONAME),)
SRCSO  += x264dll.c
OBJSO  += $(if $(RC), x264res.dll.o)
endif
endif

ifeq ($(HAVE_OPENCL),yes)
common/oclobj.h: common/opencl/x264-cl.h $(wildcard $(SRCPATH)/common/opencl/*.cl)
	cat $^ | $(SRCPATH)/tools/cltostr.sh $@
GENERATED += common/oclobj.h
SRCS_8 += common/opencl.c encoder/slicetype-cl.c
endif

OBJS   += $(SRCS:%.c=%.o)
OBJCLI += $(SRCCLI:%.c=%.o)
OBJSO  += $(SRCSO:%.c=%.o)
OBJEXAMPLE += $(SRCEXAMPLE:%.c=%.o)

ifneq ($(findstring HAVE_BITDEPTH8 1, $(CONFIG)),)
OBJS      += $(SRCS_X:%.c=%-8.o) $(SRCS_8:%.c=%-8.o)
OBJCLI    += $(SRCCLI_X:%.c=%-8.o)
OBJCHK_8  += $(SRCCHK_X:%.c=%-8.o)
checkasm: checkasm8$(EXE)
endif
ifneq ($(findstring HAVE_BITDEPTH10 1, $(CONFIG)),)
OBJS      += $(SRCS_X:%.c=%-10.o)
OBJCLI    += $(SRCCLI_X:%.c=%-10.o)
OBJCHK_10 += $(SRCCHK_X:%.c=%-10.o)
checkasm: checkasm10$(EXE)
endif

.PHONY: all default fprofiled clean distclean install install-* uninstall cli lib-* checkasm etags

cli: x264$(EXE)
lib-static: $(LIBX264)
lib-shared: $(SONAME)

$(LIBX264): $(GENERATED) .depend $(OBJS) $(OBJASM)
	rm -f $(LIBX264)
	$(AR)$@ $(OBJS) $(OBJASM)
	$(if $(RANLIB), $(RANLIB) $@)

$(SONAME): $(GENERATED) .depend $(OBJS) $(OBJASM) $(OBJSO)
	$(LD)$@ $(OBJS) $(OBJASM) $(OBJSO) $(SOFLAGS) $(LDFLAGS)

$(IMPLIBNAME): $(SONAME)

ifneq ($(EXE),)
.PHONY: x264 checkasm8 checkasm10 example
x264: x264$(EXE)
checkasm8: checkasm8$(EXE)
checkasm10: checkasm10$(EXE)
example: example$(EXE)
endif

x264$(EXE): $(GENERATED) .depend $(OBJCLI) $(CLI_LIBX264)
	$(LD)$@ $(OBJCLI) $(CLI_LIBX264) $(LDFLAGSCLI) $(LDFLAGS)

checkasm8$(EXE): $(GENERATED) .depend $(OBJCHK) $(OBJCHK_8) $(LIBX264)
	$(LD)$@ $(OBJCHK) $(OBJCHK_8) $(LIBX264) $(LDFLAGS)

checkasm10$(EXE): $(GENERATED) .depend $(OBJCHK) $(OBJCHK_10) $(LIBX264)
	$(LD)$@ $(OBJCHK) $(OBJCHK_10) $(LIBX264) $(LDFLAGS)

example$(EXE): $(GENERATED) .depend $(OBJEXAMPLE) $(LIBX264)
	$(LD)$@ $(OBJEXAMPLE) $(LIBX264) $(LDFLAGS)

$(OBJS) $(OBJSO): CFLAGS += $(CFLAGSSO)
$(OBJCLI): CFLAGS += $(CFLAGSCLI)

$(OBJS) $(OBJASM) $(OBJSO) $(OBJCLI) $(OBJCHK) $(OBJCHK_8) $(OBJCHK_10) $(OBJEXAMPLE): .depend

%.o: %.c
	$(CC) $(CFLAGS) -c $< $(CC_O)

%-8.o: %.c
	$(CC) $(CFLAGS) -c $< $(CC_O) -DHIGH_BIT_DEPTH=0 -DBIT_DEPTH=8

%-10.o: %.c
	$(CC) $(CFLAGS) -c $< $(CC_O) -DHIGH_BIT_DEPTH=1 -DBIT_DEPTH=10

%.o: %.asm common/x86/x86inc.asm common/x86/x86util.asm
	$(AS) $(ASFLAGS) -o $@ $<
	-@ $(if $(STRIP), $(STRIP) -x $@) # delete local/anonymous symbols, so they don't show up in oprofile

%-8.o: %.asm common/x86/x86inc.asm common/x86/x86util.asm
	$(AS) $(ASFLAGS) -o $@ $< -DBIT_DEPTH=8 -Dprivate_prefix=x264_8
	-@ $(if $(STRIP), $(STRIP) -x $@)

%-10.o: %.asm common/x86/x86inc.asm common/x86/x86util.asm
	$(AS) $(ASFLAGS) -o $@ $< -DBIT_DEPTH=10 -Dprivate_prefix=x264_10
	-@ $(if $(STRIP), $(STRIP) -x $@)

%.o: %.S
	$(AS) $(ASFLAGS) -o $@ $<
	-@ $(if $(STRIP), $(STRIP) -x $@) # delete local/anonymous symbols, so they don't show up in oprofile

%-8.o: %.S
	$(AS) $(ASFLAGS) -o $@ $< -DHIGH_BIT_DEPTH=0 -DBIT_DEPTH=8
	-@ $(if $(STRIP), $(STRIP) -x $@)

%-10.o: %.S
	$(AS) $(ASFLAGS) -o $@ $< -DHIGH_BIT_DEPTH=1 -DBIT_DEPTH=10
	-@ $(if $(STRIP), $(STRIP) -x $@)

%.dll.o: %.rc x264.h
	$(RC) $(RCFLAGS)$@ -DDLL $<

%.o: %.rc x264.h x264res.manifest
	$(RC) $(RCFLAGS)$@ $<

.depend: config.mak
	@rm -f .depend
	@echo 'dependency file generation...'
ifeq ($(COMPILER),CL)
	@$(foreach SRC, $(addprefix $(SRCPATH)/, $(SRCS) $(SRCCLI) $(SRCSO) $(SRCEXAMPLE)), $(SRCPATH)/tools/msvsdepend.sh "$(CC)" "$(CFLAGS)" "$(SRC)" "$(SRC:$(SRCPATH)/%.c=%.o)" 1>> .depend;)
ifneq ($(findstring HAVE_BITDEPTH8 1, $(CONFIG)),)
	@$(foreach SRC, $(addprefix $(SRCPATH)/, $(SRCS_X) $(SRCS_8) $(SRCCLI_X) $(SRCCHK_X)), $(SRCPATH)/tools/msvsdepend.sh "$(CC)" "$(CFLAGS)" "$(SRC)" "$(SRC:$(SRCPATH)/%.c=%-8.o)" 1>> .depend;)
endif
ifneq ($(findstring HAVE_BITDEPTH10 1, $(CONFIG)),)
	@$(foreach SRC, $(addprefix $(SRCPATH)/, $(SRCS_X) $(SRCCLI_X) $(SRCCHK_X)), $(SRCPATH)/tools/msvsdepend.sh "$(CC)" "$(CFLAGS)" "$(SRC)" "$(SRC:$(SRCPATH)/%.c=%-10.o)" 1>> .depend;)
endif
else
	@$(foreach SRC, $(addprefix $(SRCPATH)/, $(SRCS) $(SRCCLI) $(SRCSO) $(SRCEXAMPLE)), $(CC) $(CFLAGS) $(SRC) $(DEPMT) $(SRC:$(SRCPATH)/%.c=%.o) $(DEPMM) 1>> .depend;)
ifneq ($(findstring HAVE_BITDEPTH8 1, $(CONFIG)),)
	@$(foreach SRC, $(addprefix $(SRCPATH)/, $(SRCS_X) $(SRCS_8) $(SRCCLI_X) $(SRCCHK_X)), $(CC) $(CFLAGS) $(SRC) $(DEPMT) $(SRC:$(SRCPATH)/%.c=%-8.o) $(DEPMM) 1>> .depend;)
endif
ifneq ($(findstring HAVE_BITDEPTH10 1, $(CONFIG)),)
	@$(foreach SRC, $(addprefix $(SRCPATH)/, $(SRCS_X) $(SRCCLI_X) $(SRCCHK_X)), $(CC) $(CFLAGS) $(SRC) $(DEPMT) $(SRC:$(SRCPATH)/%.c=%-10.o) $(DEPMM) 1>> .depend;)
endif
endif

config.mak:
	./configure

depend: .depend
ifneq ($(wildcard .depend),)
include .depend
endif

OBJPROF = $(OBJS) $(OBJSO) $(OBJCLI)
# These should cover most of the important codepaths
OPT0 = --crf 30 -b1 -m1 -r1 --me dia --no-cabac --direct temporal --ssim --no-weightb
OPT1 = --crf 16 -b2 -m3 -r3 --me hex --no-8x8dct --direct spatial --no-dct-decimate -t0  --slice-max-mbs 50
OPT2 = --crf 26 -b4 -m5 -r2 --me hex --cqm jvt --nr 100 --psnr --no-mixed-refs --b-adapt 2 --slice-max-size 1500
OPT3 = --crf 18 -b3 -m9 -r5 --me umh -t1 -A all --b-pyramid normal --direct auto --no-fast-pskip --no-mbtree
OPT4 = --crf 22 -b3 -m7 -r4 --me esa -t2 -A all --psy-rd 1.0:1.0 --slices 4
OPT5 = --frames 50 --crf 24 -b3 -m10 -r3 --me tesa -t2
OPT6 = --frames 50 -q0 -m9 -r2 --me hex -Aall
OPT7 = --frames 50 -q0 -m2 -r1 --me hex --no-cabac

ifeq (,$(VIDS))
fprofiled:
	@echo 'usage: make fprofiled VIDS="infile1 infile2 ..."'
	@echo 'where infiles are anything that x264 understands,'
	@echo 'i.e. YUV with resolution in the filename, y4m, or avisynth.'
else
fprofiled: clean
	$(MAKE) x264$(EXE) CFLAGSPROF="$(PROF_GEN_CC)" LDFLAGSPROF="$(PROF_GEN_LD)"
	$(foreach V, $(VIDS), $(foreach I, 0 1 2 3 4 5 6 7, ./x264$(EXE) $(OPT$I) --threads 1 $(V) -o $(DEVNULL) ;))
ifeq ($(COMPILER),CL)
# Because Visual Studio timestamps the object files within the PGD, it fails to build if they change - only the executable should be deleted
	rm -f x264$(EXE)
else
	rm -f $(OBJPROF)
endif
	$(MAKE) CFLAGSPROF="$(PROF_USE_CC)" LDFLAGSPROF="$(PROF_USE_LD)"
	rm -f $(OBJPROF:%.o=%.gcda) $(OBJPROF:%.o=%.gcno) *.dyn pgopti.dpi pgopti.dpi.lock *.pgd *.pgc
endif

clean:
	rm -f $(OBJS) $(OBJASM) $(OBJCLI) $(OBJSO) $(GENERATED) .depend TAGS
	rm -f $(SONAME) *.a *.lib *.exp *.pdb x264$(EXE) x264_lookahead.clbin
	rm -f checkasm8$(EXE) checkasm10$(EXE) $(OBJCHK) $(OBJCHK_8) $(OBJCHK_10)
	rm -f example$(EXE) $(OBJEXAMPLE)
	rm -f $(OBJPROF:%.o=%.gcda) $(OBJPROF:%.o=%.gcno) *.dyn pgopti.dpi pgopti.dpi.lock *.pgd *.pgc

distclean: clean
	rm -f config.mak x264_config.h config.h config.log x264.pc x264.def
	rm -rf conftest*

install-cli: cli
	$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL) x264$(EXE) $(DESTDIR)$(bindir)

install-lib-dev:
	$(INSTALL) -d $(DESTDIR)$(includedir)
	$(INSTALL) -d $(DESTDIR)$(libdir)/pkgconfig
	$(INSTALL) -m 644 $(SRCPATH)/x264.h x264_config.h $(DESTDIR)$(includedir)
	$(INSTALL) -m 644 x264.pc $(DESTDIR)$(libdir)/pkgconfig

install-lib-static: lib-static install-lib-dev
	$(INSTALL) -d $(DESTDIR)$(libdir)
	$(INSTALL) -m 644 $(LIBX264) $(DESTDIR)$(libdir)
	$(if $(RANLIB), $(RANLIB) $(DESTDIR)$(libdir)/$(LIBX264))

install-lib-shared: lib-shared install-lib-dev
	$(INSTALL) -d $(DESTDIR)$(libdir)
ifneq ($(IMPLIBNAME),)
	$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL) -m 755 $(SONAME) $(DESTDIR)$(bindir)
	$(INSTALL) -m 644 $(IMPLIBNAME) $(DESTDIR)$(libdir)
else ifneq ($(SONAME),)
	ln -f -s $(SONAME) $(DESTDIR)$(libdir)/libx264.$(SOSUFFIX)
	$(INSTALL) -m 755 $(SONAME) $(DESTDIR)$(libdir)
endif

install-bashcompletion:
ifneq ($(BASHCOMPLETIONSDIR),)
	$(INSTALL) -d $(DESTDIR)$(BASHCOMPLETIONSDIR)
	$(INSTALL) -m 644 $(SRCPATH)/tools/bash-autocomplete.sh $(DESTDIR)$(BASHCOMPLETIONSDIR)/x264
endif

uninstall:
	rm -f $(DESTDIR)$(includedir)/x264.h $(DESTDIR)$(includedir)/x264_config.h $(DESTDIR)$(libdir)/libx264.a
	rm -f $(DESTDIR)$(bindir)/x264$(EXE) $(DESTDIR)$(libdir)/pkgconfig/x264.pc
ifneq ($(IMPLIBNAME),)
	rm -f $(DESTDIR)$(bindir)/$(SONAME) $(DESTDIR)$(libdir)/$(IMPLIBNAME)
else ifneq ($(SONAME),)
	rm -f $(DESTDIR)$(libdir)/$(SONAME) $(DESTDIR)$(libdir)/libx264.$(SOSUFFIX)
endif
ifneq ($(BASHCOMPLETIONSDIR),)
	rm -f $(DESTDIR)$(BASHCOMPLETIONSDIR)/x264
endif

etags TAGS:
	etags $(SRCS) $(SRCS_X) $(SRCS_8)
