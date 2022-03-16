#!/usr/bin/env python

import operator

from optparse import OptionGroup

import sys

from time import time

from digress.cli import Dispatcher as _Dispatcher
from digress.errors import ComparisonError, FailedTestError, DisabledTestError
from digress.testing import depends, comparer, Fixture, Case
from digress.comparers import compare_pass
from digress.scm import git as x264git

from subprocess import Popen, PIPE, STDOUT

import os
import re
import shlex
import inspect

from random import randrange, seed
from math import ceil

from itertools import imap, izip

os.chdir(os.path.join(os.path.dirname(__file__), ".."))

# options

OPTIONS = [
    [ "--tune %s" % t for t in ("film", "zerolatency") ],
    ("", "--intra-refresh"),
    ("", "--no-cabac"),
    ("", "--interlaced"),
    ("", "--slice-max-size 1000"),
    ("", "--frame-packing 5"),
    [ "--preset %s" % p for p in ("ultrafast",
                                  "superfast",
                                  "veryfast",
                                  "faster",
                                  "fast",
                                  "medium",
                                  "slow",
                                  "slower",
                                  "veryslow",
                                  "placebo") ]
]

# end options

def compare_yuv_output(width, height):
    def _compare_yuv_output(file_a, file_b):
        size_a = os.path.getsize(file_a)
        size_b = os.path.getsize(file_b)

        if size_a != size_b:
            raise ComparisonError("%s is not the same size as %s" % (
                file_a,
                file_b
            ))

        BUFFER_SIZE = 8196

        offset = 0

        with open(file_a) as f_a:
            with open(file_b) as f_b:
                for chunk_a, chunk_b in izip(
                    imap(
                        lambda i: f_a.read(BUFFER_SIZE),
                        xrange(size_a // BUFFER_SIZE + 1)
                    ),
                    imap(
                        lambda i: f_b.read(BUFFER_SIZE),
                        xrange(size_b // BUFFER_SIZE + 1)
                    )
                ):
                    chunk_size = len(chunk_a)

                    if chunk_a != chunk_b:
                        for i in xrange(chunk_size):
                            if chunk_a[i] != chunk_b[i]:
                                # calculate the macroblock, plane and frame from the offset
                                offs = offset + i

                                y_plane_area = width * height
                                u_plane_area = y_plane_area + y_plane_area * 0.25
                                v_plane_area = u_plane_area + y_plane_area * 0.25

                                pixel = offs % v_plane_area
                                frame = offs // v_plane_area

                                if pixel < y_plane_area:
                                    plane = "Y"

                                    pixel_x = pixel % width
                                    pixel_y = pixel // width

                                    macroblock = (ceil(pixel_x / 16.0), ceil(pixel_y / 16.0))
                                elif pixel < u_plane_area:
                                    plane = "U"

                                    pixel -= y_plane_area

                                    pixel_x = pixel % width
                                    pixel_y = pixel // width

                                    macroblock = (ceil(pixel_x / 8.0), ceil(pixel_y / 8.0))
                                else:
                                    plane = "V"

                                    pixel -= u_plane_area

                                    pixel_x = pixel % width
                                    pixel_y = pixel // width

                                    macroblock = (ceil(pixel_x / 8.0), ceil(pixel_y / 8.0))

                                macroblock = tuple([ int(x) for x in macroblock ])

                                raise ComparisonError("%s differs from %s at frame %d, " \
                                                      "macroblock %s on the %s plane (offset %d)" % (
                                    file_a,
                                    file_b,
                                    frame,
                                    macroblock,
                                    plane,
                                    offs)
                                )

                    offset += chunk_size

    return _compare_yuv_output

def program_exists(program):
    def is_exe(fpath):
        return os.path.exists(fpath) and os.access(fpath, os.X_OK)

    fpath, fname = os.path.split(program)

    if fpath:
        if is_exe(program):
            return program
    else:
        for path in os.environ["PATH"].split(os.pathsep):
            exe_file = os.path.join(path, program)
            if is_exe(exe_file):
                return exe_file

    return None

class x264(Fixture):
    scm = x264git

class Compile(Case):
    @comparer(compare_pass)
    def test_configure(self):
        Popen([
            "make",
            "distclean"
        ], stdout=PIPE, stderr=STDOUT).communicate()

        configure_proc = Popen([
            "./configure"
        ] + self.fixture.dispatcher.configure, stdout=PIPE, stderr=STDOUT)

        output = configure_proc.communicate()[0]
        if configure_proc.returncode != 0:
            raise FailedTestError("configure failed: %s" % output.replace("\n", " "))

    @depends("configure")
    @comparer(compare_pass)
    def test_make(self):
        make_proc = Popen([
            "make",
            "-j5"
        ], stdout=PIPE, stderr=STDOUT)

        output = make_proc.communicate()[0]
        if make_proc.returncode != 0:
            raise FailedTestError("make failed: %s" % output.replace("\n", " "))

_dimension_pattern = re.compile(r"\w+ [[]info[]]: (\d+)x(\d+)[pi] \d+:\d+ @ \d+/\d+ fps [(][vc]fr[)]")

def _YUVOutputComparisonFactory():
    class YUVOutputComparison(Case):
        _dimension_pattern = _dimension_pattern

        depends = [ Compile ]
        options = []

        def __init__(self):
            for name, meth in inspect.getmembers(self):
                if name[:5] == "test_" and name[5:] not in self.fixture.dispatcher.yuv_tests:
                    delattr(self.__class__, name)

        def _run_x264(self):
            x264_proc = Popen([
                "./x264",
                "-o",
                "%s.264" % self.fixture.dispatcher.video,
                "--dump-yuv",
                "x264-output.yuv"
            ] + self.options + [
                self.fixture.dispatcher.video
            ], stdout=PIPE, stderr=STDOUT)

            output = x264_proc.communicate()[0]
            if x264_proc.returncode != 0:
                raise FailedTestError("x264 did not complete properly: %s" % output.replace("\n", " "))

            matches = _dimension_pattern.match(output)

            return (int(matches.group(1)), int(matches.group(2)))

        @comparer(compare_pass)
        def test_jm(self):
            if not program_exists("ldecod"): raise DisabledTestError("jm unavailable")

            try:
                runres = self._run_x264()

                jm_proc = Popen([
                    "ldecod",
                    "-i",
                    "%s.264" % self.fixture.dispatcher.video,
                    "-o",
                    "jm-output.yuv"
                ], stdout=PIPE, stderr=STDOUT)

                output = jm_proc.communicate()[0]
                if jm_proc.returncode != 0:
                    raise FailedTestError("jm did not complete properly: %s" % output.replace("\n", " "))

                try:
                    compare_yuv_output(*runres)("x264-output.yuv", "jm-output.yuv")
                except ComparisonError, e:
                    raise FailedTestError(e)
            finally:
                try: os.remove("x264-output.yuv")
                except: pass

                try: os.remove("%s.264" % self.fixture.dispatcher.video)
                except: pass

                try: os.remove("jm-output.yuv")
                except: pass

                try: os.remove("log.dec")
                except: pass

                try: os.remove("dataDec.txt")
                except: pass

        @comparer(compare_pass)
        def test_ffmpeg(self):
            if not program_exists("ffmpeg"): raise DisabledTestError("ffmpeg unavailable")
            try:
                runres = self._run_x264()

                ffmpeg_proc = Popen([
                    "ffmpeg",
                    "-vsync 0",
                    "-i",
                    "%s.264" % self.fixture.dispatcher.video,
                    "ffmpeg-output.yuv"
                ], stdout=PIPE, stderr=STDOUT)

                output = ffmpeg_proc.communicate()[0]
                if ffmpeg_proc.returncode != 0:
                    raise FailedTestError("ffmpeg did not complete properly: %s" % output.replace("\n", " "))

                try:
                    compare_yuv_output(*runres)("x264-output.yuv", "ffmpeg-output.yuv")
                except ComparisonError, e:
                    raise FailedTestError(e)
            finally:
                try: os.remove("x264-output.yuv")
                except: pass

                try: os.remove("%s.264" % self.fixture.dispatcher.video)
                except: pass

                try: os.remove("ffmpeg-output.yuv")
                except: pass

    return YUVOutputComparison

class Regression(Case):
    depends = [ Compile ]

    _psnr_pattern = re.compile(r"x264 [[]info[]]: PSNR Mean Y:\d+[.]\d+ U:\d+[.]\d+ V:\d+[.]\d+ Avg:\d+[.]\d+ Global:(\d+[.]\d+) kb/s:\d+[.]\d+")
    _ssim_pattern = re.compile(r"x264 [[]info[]]: SSIM Mean Y:(\d+[.]\d+) [(]\d+[.]\d+db[)]")

    def __init__(self):
        if self.fixture.dispatcher.x264:
            self.__class__.__name__ += " %s" % " ".join(self.fixture.dispatcher.x264)

    def test_psnr(self):
        try:
            x264_proc = Popen([
                "./x264",
                "-o",
                "%s.264" % self.fixture.dispatcher.video,
                "--psnr"
            ] + self.fixture.dispatcher.x264 + [
                self.fixture.dispatcher.video
            ], stdout=PIPE, stderr=STDOUT)

            output = x264_proc.communicate()[0]

            if x264_proc.returncode != 0:
                raise FailedTestError("x264 did not complete properly: %s" % output.replace("\n", " "))

            for line in output.split("\n"):
                if line.startswith("x264 [info]: PSNR Mean"):
                    return float(self._psnr_pattern.match(line).group(1))

            raise FailedTestError("no PSNR output caught from x264")
        finally:
            try: os.remove("%s.264" % self.fixture.dispatcher.video)
            except: pass

    def test_ssim(self):
        try:
            x264_proc = Popen([
                "./x264",
                "-o",
                "%s.264" % self.fixture.dispatcher.video,
                "--ssim"
            ] + self.fixture.dispatcher.x264 + [
                self.fixture.dispatcher.video
            ], stdout=PIPE, stderr=STDOUT)

            output = x264_proc.communicate()[0]

            if x264_proc.returncode != 0:
                raise FailedTestError("x264 did not complete properly: %s" % output.replace("\n", " "))

            for line in output.split("\n"):
                if line.startswith("x264 [info]: SSIM Mean"):
                    return float(self._ssim_pattern.match(line).group(1))

            raise FailedTestError("no PSNR output caught from x264")
        finally:
            try: os.remove("%s.264" % self.fixture.dispatcher.video)
            except: pass

def _generate_random_commandline():
    commandline = []

    for suboptions in OPTIONS:
        commandline.append(suboptions[randrange(0, len(suboptions))])

    return filter(None, reduce(operator.add, [ shlex.split(opt) for opt in commandline ]))

_generated = []

fixture = x264()
fixture.register_case(Compile)

fixture.register_case(Regression)

class Dispatcher(_Dispatcher):
    video = "akiyo_qcif.y4m"
    products = 50
    configure = []
    x264 = []
    yuv_tests = [ "jm" ]

    def _populate_parser(self):
        super(Dispatcher, self)._populate_parser()

        # don't do a whole lot with this
        tcase = _YUVOutputComparisonFactory()

        yuv_tests = [ name[5:] for name, meth in filter(lambda pair: pair[0][:5] == "test_", inspect.getmembers(tcase)) ]

        group = OptionGroup(self.optparse, "x264 testing-specific options")

        group.add_option(
            "-v",
            "--video",
            metavar="FILENAME",
            action="callback",
            dest="video",
            type=str,
            callback=lambda option, opt, value, parser: setattr(self, "video", value),
            help="yuv video to perform testing on (default: %s)" % self.video
        )

        group.add_option(
            "-s",
            "--seed",
            metavar="SEED",
            action="callback",
            dest="seed",
            type=int,
            callback=lambda option, opt, value, parser: setattr(self, "seed", value),
            help="seed for the random number generator (default: unix timestamp)"
        )

        group.add_option(
            "-p",
            "--product-tests",
            metavar="NUM",
            action="callback",
            dest="video",
            type=int,
            callback=lambda option, opt, value, parser: setattr(self, "products", value),
            help="number of cartesian products to generate for yuv comparison testing (default: %d)" % self.products
        )

        group.add_option(
            "--configure-with",
            metavar="FLAGS",
            action="callback",
            dest="configure",
            type=str,
            callback=lambda option, opt, value, parser: setattr(self, "configure", shlex.split(value)),
            help="options to run ./configure with"
        )

        group.add_option(
            "--yuv-tests",
            action="callback",
            dest="yuv_tests",
            type=str,
            callback=lambda option, opt, value, parser: setattr(self, "yuv_tests", [
                val.strip() for val in value.split(",")
            ]),
            help="select tests to run with yuv comparisons (default: %s, available: %s)" % (
                ", ".join(self.yuv_tests),
                ", ".join(yuv_tests)
            )
        )

        group.add_option(
            "--x264-with",
            metavar="FLAGS",
            action="callback",
            dest="x264",
            type=str,
            callback=lambda option, opt, value, parser: setattr(self, "x264", shlex.split(value)),
            help="additional options to run ./x264 with"
        )

        self.optparse.add_option_group(group)

    def pre_dispatch(self):
        if not hasattr(self, "seed"):
            self.seed = int(time())

        print "Using seed: %d" % self.seed
        seed(self.seed)

        for i in xrange(self.products):
            YUVOutputComparison = _YUVOutputComparisonFactory()

            commandline = _generate_random_commandline()

            counter = 0

            while commandline in _generated:
                counter += 1
                commandline = _generate_random_commandline()

                if counter > 100:
                    print >>sys.stderr, "Maximum command-line regeneration exceeded. "  \
                                        "Try a different seed or specify fewer products to generate."
                    sys.exit(1)

            commandline += self.x264

            _generated.append(commandline)

            YUVOutputComparison.options = commandline
            YUVOutputComparison.__name__ = ("%s %s" % (YUVOutputComparison.__name__, " ".join(commandline)))

            fixture.register_case(YUVOutputComparison)

Dispatcher(fixture).dispatch()
