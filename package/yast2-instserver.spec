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
Version:        3.1.1
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:	        System/YaST
License:        GPL-2.0+
BuildRequires:  perl-XML-Writer update-desktop-files yast2 yast2-testsuite
BuildRequires:  yast2-devtools >= 3.1.10

# ag_content agent
# Wizard::SetDesktopTitleAndIcon
Requires:	yast2 >= 2.21.22

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - Installation Server Configuration and Management

%description
This package allows you to configure an installation server suitable
for installaing SUSE Linux over the network. Currently FTP, HTTP and
NFS sources are supported.

%package devel-doc
Requires:       yast2-instserver = %version
Group:          System/YaST
Summary:        YaST2 - Installation Server - Development Documentation

%description devel-doc
This package contains development documentation for using the API
provided by this package.


%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


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
%doc %{yast_docdir}/COPYING

%files devel-doc
%doc %{yast_docdir}/autodocs
