Name:       rlottie
Summary:    rlottie ibrary
Version:    0.0.1
Release:    1
Group:      UI Framework/Services
License:    LGPL-v2.1
URL:        http://www.tizen.org/
Source0:    %{name}-%{version}.tar.gz
BuildRequires:  cmake
Requires(post): /sbin/ldconfig
Requires(postun): /sbin/ldconfig

%description
lottie player library


%package devel
Summary:    lottie player library (devel)
Group:      Development/Libraries
Requires:   %{name} = %{version}-%{release}


%description devel
lottie player library (devel)


%prep
%setup -q


%build
export CFLAGS+=" -fvisibility=hidden -fPIC -Wall -O2"
export LDFLAGS+=" "

%ifarch %{arm}
export CXXFLAGS+=" -D_ARCH_ARM_ -mfpu=neon"
%endif


%ifarch %{arm}
cmake . -DCMAKE_INSTALL_PREFIX=/usr \
        -DLIB_INSTALL_DIR:PATH=%{_libdir} \
        -DARCH="arm"
%else
cmake . -DCMAKE_INSTALL_PREFIX=/usr \
        -DLIB_INSTALL_DIR:PATH=%{_libdir}
%endif


make %{?jobs:-j%jobs}

%install
%make_install

%files
%defattr(-,root,root,-)
%{_libdir}/librlottie.so.*
%manifest %{name}.manifest
%license COPYING licenses/COPYING*

%files devel
%defattr(-,root,root,-)
%{_includedir}/*.h
%{_libdir}/librlottie.so

%{_libdir}/cmake/rlottie/*.cmake
%{_libdir}/pkgconfig/lottie-player.pc
%{_libdir}/pkgconfig/rlottie.pc
