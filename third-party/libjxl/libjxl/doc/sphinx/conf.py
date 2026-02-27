# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Configuration file for the Sphinx documentation builder.
#
# See https://www.sphinx-doc.org/en/master/usage/configuration.html

import os
import re
import subprocess

def GetVersion():
    """Function to get the version of the current code."""
    with open(os.path.join(
            os.path.dirname(__file__), '../../lib/CMakeLists.txt'), 'r') as f:
        cmakevars = {}
        for line in f:
            m = re.match(r'set\(JPEGXL_([A-Z]+)_VERSION ([^\)]+)\)', line)
            if m:
                cmakevars[m.group(1)] = m.group(2)
    return '%s.%s.%s' % (cmakevars['MAJOR'], cmakevars['MINOR'], cmakevars['PATCH'])

def ConfigProject(app, config):
    # Configure the doxygen xml directory as the "xml" directory next to the
    # sphinx output directory. Doxygen generates by default the xml files in a
    # "xml" sub-directory of the OUTPUT_DIRECTORY.
    build_dir = os.path.dirname(app.outdir)
    xml_dir = os.path.join(build_dir, 'xml')
    config.breathe_projects['libjxl'] = xml_dir

    # Read the docs build environment doesn't run our cmake script so instead we
    # need to run doxygen manually here.
    if os.environ.get('READTHEDOCS', None) != 'True':
        return
    root_dir = os.path.realpath(os.path.join(app.srcdir, '../../'))
    doxyfile = os.path.join(build_dir, 'Doxyfile-rtd.doc')
    with open(doxyfile, 'w') as f:
        f.write(f"""
FILE_PATTERNS          = *.c *.h
GENERATE_HTML          = NO
GENERATE_LATEX         = NO
GENERATE_XML           = YES
INPUT                  = lib/include doc/api.txt
OUTPUT_DIRECTORY       = {build_dir}
PROJECT_NAME           = LIBJXL
QUIET                  = YES
RECURSIVE              = YES
STRIP_FROM_PATH        = lib/include
WARN_AS_ERROR          = YES
""")
    subprocess.check_call(['doxygen', doxyfile], cwd=root_dir)

def setup(app):
    # Generate doxygen XML on init when running from Read the docs.
    app.connect("config-inited", ConfigProject)

### Project information

project = 'libjxl'
project_copyright = 'JPEG XL Project Authors'
author = 'JPEG XL Project Authors'
version = GetVersion()

### General configuration

extensions = [
    # For integration with doxygen documentation.
    'breathe',
    # sphinx readthedocs theme.
    'sphinx_rtd_theme',
    # Do we use it?
    'sphinx.ext.graphviz',
]

breathe_default_project = 'libjxl'
breathe_projects = {}


# All the API is in C, except those files that end with cxx.h.
breathe_domain_by_extension = {'h': 'cpp'}
breathe_domain_by_file_pattern = {
    '*cxx.h': 'cpp',
}
breathe_implementation_filename_extensions = ['.cc']

# These are defined at build time by cmake.
c_id_attributes = [
    'JXL_EXPORT',
    'JXL_DEPRECATED',
    'JXL_THREADS_EXPORT',
]
cpp_id_attributes = c_id_attributes


breathe_projects_source = {
    'libjxl' : ('../../', [
        'doc/api.txt',
        'lib/include/jxl',
    ])
}

# Recognized suffixes.
source_suffix = ['.rst', '.md']

### Options for HTML output

# Use the readthedocs.io theme when generating the HTML output.
html_theme = 'sphinx_rtd_theme'
