{ lib
, fetchurl
, stdenv
, fetchzip
, ant
, jdk
, makeWrapper
, callPackage
}:

let
  minimalJavaVersion = "11";

  newsPlugin = fetchurl {
    url = "https://www.tvbrowser.org/data/uploads/1372016422809_543/NewsPlugin.jar";
    hash = "sha256-5XoypuMd2AFBE2SJ6EdECuvq6D81HLLuu9UoA9kcKAM=";
  };
in
assert lib.versionAtLeast jdk.version minimalJavaVersion;
stdenv.mkDerivation rec {
  pname = "tvbrowser";
  version = "4.2.7";

  src = fetchzip {
    url = "mirror://sourceforge/${pname}/TV-Browser%20Releases%20%28Java%20${minimalJavaVersion}%20and%20higher%29/${version}/${pname}_${version}_src.tar.gz";
    hash = "sha256-dmNfI6T0MU7UtMH+C/2hiAeDwZlFCB4JofQViZezoqI=";
  };

  nativeBuildInputs = [ ant jdk makeWrapper ];

  buildPhase = ''
    runHook preBuild

    ant runtime-linux -Dnewsplugin.url=file://${newsPlugin}
    ant tvbrowser-desktop-entry

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/${pname}
    cp -R runtime/tvbrowser_linux/* $out/share/${pname}
    rm $out/share/${pname}/${pname}.sh

    mkdir -p $out/share/applications
    mv -t $out/share/applications $out/share/${pname}/${pname}.desktop
    sed -e 's|=imgs/|='$out'/share/${pname}/imgs/|'  \
        -e 's|=${pname}.sh|='$out'/bin/${pname}|'  \
        -i $out/share/applications/${pname}.desktop

    for i in 16 32 48 128; do
      mkdir -p $out/share/icons/hicolor/''${i}x''${i}/apps
      ln -s $out/share/${pname}/imgs/${pname}$i.png $out/share/icons/hicolor/''${i}x''${i}/apps/${pname}.png
    done

    mkdir -p $out/bin
    makeWrapper ${jdk}/bin/java $out/bin/${pname}  \
      --add-flags "--module-path=lib:${pname}.jar -m ${pname}/tvbrowser.TVBrowser"  \
      --chdir "$out/share/${pname}"

    runHook postInstall
  '';

  passthru.tests.startwindow = callPackage ./test.nix {};

  meta = with lib; {
    description = "Electronic TV Program Guide";
    homepage = "https://www.tvbrowser.org/";
    sourceProvenance = with sourceTypes; [ binaryBytecode fromSource ];
    license = licenses.gpl3;
    platforms = platforms.linux;
    maintainers = with maintainers; [ jfrankenau yarny ];
  };
}
