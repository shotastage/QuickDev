Name:           quickdev
Version:        0.0.1
Release:        1%{?dist}
Summary:        QuickDev CLI for local project discovery and indexing

License:        MIT
URL:            https://github.com/shotastage/QuickDev
Source0:        https://github.com/shotastage/QuickDev/releases/download/v%{version}/quickdev-%{version}-linux-x86_64.tar.gz

BuildArch:      x86_64

%description
QuickDev scans local development directories, classifies project types,
and stores deterministic metadata for later lifecycle operations.

%prep
%setup -q

%build
# No build step: this package consumes a prebuilt release archive.

%install
install -D -m 0755 bin/qd %{buildroot}%{_bindir}/qd
install -D -m 0644 LICENSE %{buildroot}%{_licensedir}/quickdev/LICENSE

%check
%{buildroot}%{_bindir}/qd --help >/dev/null

%files
%license %{_licensedir}/quickdev/LICENSE
%{_bindir}/qd

%changelog
* Sun Apr 05 2026 QuickDev Maintainers <maintainers@example.com> - 0.0.1-1
- Initial RPM spec template.
