#
# spec file for package yast2-instserver
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-instserver
Version:        3.1.5
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2
Source1:        inst_server.conf.in

url:            http://github.com/yast/yast-instserver
Group:	        System/YaST
License:        GPL-2.0+
BuildRequires:  yast2
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  rubygem(rspec)
BuildRequires:  rubygem(yast-rake)

# ag_content agent
# Wizard::SetDesktopTitleAndIcon
Requires:	yast2 >= 2.21.22

BuildArch:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - Installation Server Configuration and Management

%description
This package allows you to configure an installation server suitable
for installaing SUSE Linux over the network. Currently FTP, HTTP and
NFS sources are supported.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%build

%install
rake install DESTDIR="%{buildroot}"
install -D %{SOURCE1} %{buildroot}/etc/apache2/conf.d/inst_server.conf.in
mkdir -p %{buildroot}/etc/YaST2/instserver


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/instserver
%{yast_yncludedir}/instserver/*
%{yast_clientdir}/instserver.rb
%{yast_moduledir}/Instserver.*
%{yast_desktopdir}/instserver.desktop
/etc/YaST2/instserver
/etc/apache2/conf.d/inst_server.conf.in
%dir /etc/apache2
%dir /etc/apache2/conf.d
%dir %{yast_docdir}
%doc %{yast_docdir}/CONTRIBUTING.md
%doc %{yast_docdir}/COPYING
%doc %{yast_docdir}/README.md
