These scripts provide a simple way to generate HTML reports of the code coverage
of your Xcode 4.5 project.
For a detailed blog post, see http://qualitycoding.org/xcode-code-coverage/


Installation
============

1. Fork this repository; you're probably going to want to make your own
modifications.
2. Place the XcodeCoverage folder in the same folder as your Xcode project.
3. [Dowload lcov-1.10](http://downloads.sourceforge.net/ltp/lcov-1.10.tar.gz).
Place the lcov-1.10 folder inside the XcodeCoverage folder.
4. Get Xcode's coverage instrumentation by going to Xcode Preferences, into Downloads, and installing Command Line Tools.
5. In your Xcode project, enable these two build settings at the project level
for your Debug configuration only:
  * Instrument Program Flow
  * Generate Test Coverage Files
6. In your main target, add a Run Script build phase to execute
``XcodeCoverage/exportenv.sh``

A few people have been tripped up by the last step: Make sure you add the
script to your main target (your app or library), not your test target.


Execution
=========

1. Run your unit tests
2. In Terminal, cd to your project's XcodeCoverage folder, then

        $ ./getcov

If you make changes to your test code without changing the production code and
want a clean slate, use the ``cleancov`` script:

    $ ./cleancov

If you make changes to your production code, you should clear out all build
artifacts before measuring code coverage again. "Clean Build Folder" by holding
down the Option key in Xcode's "Product" menu.


Modification
============

There are two places you may want to modify:

1. In envcov.sh, ``LCOV_INFO`` determines the name shown in the report.
2. In getcov, edit ``exclude_data()`` to specify which files to exclude, for
example, third-party libraries.


More resources
==============

* [Sources](https://github.com/jonreid/XcodeCoverage)
* Testing tools: [OCHamcrest](https://github.com/hamcrest/OCHamcrest),
[OCMockito](https://github.com/jonreid/OCMockito),
[JMRTestTools](https://github.com/jonreid/JMRTestTools)
* [Quality Coding](http://qualitycoding.org/) blog - Tools, tips & techniques
for _building quality in_ to iOS development
