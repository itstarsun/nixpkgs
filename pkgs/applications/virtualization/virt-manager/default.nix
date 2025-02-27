{ lib, fetchFromGitHub, python3, intltool, file, wrapGAppsHook, gtk-vnc
, vte, avahi, dconf, gobject-introspection, libvirt-glib, system-libvirt
, gsettings-desktop-schemas, libosinfo, gnome, gtksourceview4, docutils, cpio
, e2fsprogs, findutils, gzip, cdrtools, xorriso, fetchpatch
, desktopToDarwinBundle, stdenv
, spiceSupport ? true, spice-gtk ? null
}:

python3.pkgs.buildPythonApplication rec {
  pname = "virt-manager";
  version = "4.1.0";

  src = fetchFromGitHub {
    owner = pname;
    repo = pname;
    rev = "v${version}";
    hash = "sha256-UgZ58WLXq0U3EDt4311kv0kayVU17In4kwnQ+QN1E7A=";
  };

  nativeBuildInputs = [
    intltool file
    gobject-introspection # for setup hook populating GI_TYPELIB_PATH
    docutils
  ] ++ lib.optional stdenv.isDarwin desktopToDarwinBundle;

  buildInputs = [
    wrapGAppsHook
    libvirt-glib vte dconf gtk-vnc gnome.adwaita-icon-theme avahi
    gsettings-desktop-schemas libosinfo gtksourceview4
  ] ++ lib.optional spiceSupport spice-gtk;

  propagatedBuildInputs = with python3.pkgs; [
    pygobject3 libvirt libxml2 requests cdrtools
  ];

  postPatch = ''
    sed -i 's|/usr/share/libvirt/cpu_map.xml|${system-libvirt}/share/libvirt/cpu_map.xml|g' virtinst/capabilities.py
    sed -i "/'install_egg_info'/d" setup.py
  '';

  postConfigure = ''
    ${python3.interpreter} setup.py configure --prefix=$out
  '';

  setupPyGlobalFlags = [ "--no-update-icon-cache" "--no-compile-schemas" ];

  dontWrapGApps = true;

  preFixup = ''
    glib-compile-schemas $out/share/gsettings-schemas/${pname}-${version}/glib-2.0/schemas

    gappsWrapperArgs+=(--set PYTHONPATH "$PYTHONPATH")
    # these are called from virt-install in initrdinject.py
    gappsWrapperArgs+=(--prefix PATH : "${lib.makeBinPath [ cpio e2fsprogs file findutils gzip ]}")

    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")

    # Fixes testCLI0051virt_install_initrd_inject on Darwin: "cpio: root:root: invalid group"
    substituteInPlace virtinst/install/installerinject.py \
      --replace "'--owner=root:root'" "'--owner=0:0'"
  '';

  nativeCheckInputs = with python3.pkgs; [
    pytestCheckHook
    cpio
    cdrtools
    xorriso
  ];

  disabledTests = [
    "testAlterDisk"
    "test_misc_nonpredicatble_generate"
    "test_disk_dir_searchable"  # does something strange with permissions
    "testCLI0001virt_install_many_devices"  # expects /var to exist
  ];

  preCheck = ''
    export HOME=.
  ''; # <- Required for "tests/test_urldetect.py".

  postCheck = ''
    $out/bin/virt-manager --version | grep -Fw ${version} > /dev/null
  '';

  meta = with lib; {
    homepage = "https://virt-manager.org";
    description = "Desktop user interface for managing virtual machines";
    longDescription = ''
      The virt-manager application is a desktop user interface for managing
      virtual machines through libvirt. It primarily targets KVM VMs, but also
      manages Xen and LXC (linux containers).
    '';
    license = licenses.gpl2;
    platforms = platforms.unix;
    mainProgram = "virt-manager";
    maintainers = with maintainers; [ qknight offline fpletz globin ];
  };
}
