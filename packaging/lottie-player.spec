Name:       lottie-player
Summary:    lottie player library
Version:    0.0.1
Release:    1
Group:      UI Framework/Services
License:    Apache-2.0
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

mkdir -p %{buildroot}/%{_datadir}/license
cp %{_builddir}/%{buildsubdir}/COPYING %{buildroot}/%{_datadir}/license/COPYING
cp %{_builddir}/%{buildsubdir}/licenses/* %{buildroot}/%{_datadir}/license/

%files
%defattr(-,root,root,-)
%{_libdir}/liblottie-player.so.*
%{_datadir}/license/COPYING*
%manifest %{name}.manifest

%files devel
%defattr(-,root,root,-)
%{_includedir}/*.h
%{_libdir}/liblottie-player.so
%{_libdir}/cmake/lottie-player/*.cmake
%{_libdir}/pkgconfig/lottie-player.pc
