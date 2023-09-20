Name: cray-spire-dracut
Vendor: Hewlett Packard Enterprise Company
Version: %(echo $VERSION | sed 's/^v//')
Release: 5
Source: %{name}-%{version}.tar.bz2
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}
Group: System/Management
License: MIT
Summary: Cray Spire Dracut Module

Requires: spire-agent
Requires: tpm-provisioner-client
Requires: coreutils
Requires: dracut
Requires: iputils
Requires: curl
Requires: jq

%define dracut_modules /usr/lib/dracut/modules.d
%define spire_dracut_doc /opt/cray/cray-spire-dracut/doc

%description

%prep
%setup

%build

%install
%{__mkdir_p} %{buildroot}%{dracut_modules}/95crayspire
%{__mkdir_p} %{buildroot}%{spire_dracut_doc}
%{__install} -m 0644 module-setup.sh parse-crayspire.sh cray-spire-finished.sh cray-spire-pre-pivot.sh cray-dump-spire-log.sh %{buildroot}%{dracut_modules}/95crayspire
%{__install} -m 0644 parse-crayspire-mdserver.sh cray-spire-mdserver-finished.sh %{buildroot}%{dracut_modules}/95crayspire
%{__install} -m 0644 README.md %{buildroot}%{spire_dracut_doc}

%files
%defattr(0644, root, root)

%dir %{dracut_modules}/95crayspire
%{dracut_modules}/95crayspire/*.sh
%dir %{spire_dracut_doc}
%attr(644, root, root) %{spire_dracut_doc}/README.md

%post

%preun

%changelog
