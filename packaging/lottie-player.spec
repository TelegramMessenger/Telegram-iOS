Name:       lottie-player
Summary:    lottie player library
Version:    0.0.1
Release:    1
Group:      System/Libraries
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
export CFLAGS+=" -fvisibility=hidden -fPIC -Wall"
export LDFLAGS+=" "


cmake \
    . -DCMAKE_INSTALL_PREFIX=/usr


make %{?jobs:-j%jobs}

%install
%make_install

mkdir -p %{buildroot}/%{_datadir}/license
cp %{_builddir}/%{buildsubdir}/LICENSE %{buildroot}/%{_datadir}/license/%{name}


%post -p /sbin/ldconfig
echo "INFO: System should be restarted or execute: systemctl --user daemon-reload from user session to finish service installation."
%postun -p /sbin/ldconfig


%files
%defattr(-,root,root,-)
%{_libdir}/liblottie-player.so*
%{_datadir}/license/%{name}
%manifest %{name}.manifest

%files devel
%defattr(-,root,root,-)
%{_includedir}/*.h
%{_libdir}/cmake/lottie-player/*.cmake
%{_libdir}/pkgconfig/lottie-player.pc



