Name:       lottie-player
Summary:    rlottie Library
Version:    0.0.1
Release:    1
Group:      UI Framework/Services
License:    LGPL-v2.1
URL:        http://www.tizen.org/
Source0:    %{name}-%{version}.tar.gz
BuildRequires:  meson
BuildRequires:  ninja
Requires(post): /sbin/ldconfig
Requires(postun): /sbin/ldconfig

%description
rlottie library


%package devel
Summary:    rlottie library (devel)
Group:      Development/Libraries
Requires:   %{name} = %{version}-%{release}


%description devel
rlottie library (devel)


%prep
%setup -q


%build

export DESTDIR=%{buildroot}

export CXXFLAGS+=" -std=gnu++14"

meson setup \
                --prefix /usr \
                --libdir %{_libdir} \
                builddir 2>&1
ninja \
      -C builddir \
      -j %(echo "`/usr/bin/getconf _NPROCESSORS_ONLN`")

%install

export DESTDIR=%{buildroot}

ninja -C builddir install

%files
%defattr(-,root,root,-)
%{_libdir}/librlottie.so.*
%{_libdir}/librlottie-image-loader.so*
%manifest packaging/rlottie.manifest
%license COPYING licenses/COPYING*

%files devel
%defattr(-,root,root,-)
%{_includedir}/*.h
%{_libdir}/librlottie.so
%{_libdir}/librlottie-image-loader.so

%{_libdir}/pkgconfig/rlottie.pc
