#!/bin/bash

# Este script genera la aplicación NativeTouch y resetea los permisos para evitar bloqueos

APP_NAME="NativeTouch.app"
EXECUTABLE_NAME="NativeTouch"
SOURCE_FILES="src/*.swift"

echo "🧹 Limpiando build anterior..."
rm -rf "$APP_NAME"

echo "📁 Creando estructura de la aplicación..."
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

# Generate or copy icon
ICON_SOURCE_DIR="icons/AppIcons/Assets.xcassets/AppIcon.appiconset"
ICON_FALLBACK="/Users/pedrocasaubon/OrganizedDownloads/Compressed/AppIcons/Assets.xcassets/AppIcon.appiconset"
ICON_DEST_FILE="$APP_NAME/Contents/Resources/NativeTouch.icns"

if [ -d "$ICON_SOURCE_DIR" ]; then
    use_icon_source="$ICON_SOURCE_DIR"
elif [ -d "$ICON_FALLBACK" ]; then
    use_icon_source="$ICON_FALLBACK"
else
    use_icon_source=""
fi

if [ -n "$use_icon_source" ]; then
    echo "🖼️ Generando icns desde AppIcon.appiconset ($use_icon_source)..."

    # Create temporary iconset expected by iconutil
    TMP_ICONSET="/tmp/NativeTouch.iconset"
    rm -rf "$TMP_ICONSET"
    mkdir -p "$TMP_ICONSET"

    python3 - <<PYTHON
import json, os, shutil, sys
src = os.path.join(os.getcwd(), '$use_icon_source')
out = '$TMP_ICONSET'
with open(os.path.join(src, 'Contents.json'), 'r') as f:
    data = json.load(f)
for image in data.get('images', []):
    filename = image.get('filename')
    if not filename: continue
    idiom = image.get('scale')
    if '@' in filename:
        base=f"icon_{filename.replace('.png','')}"
    else:
        base=filename.replace('.png','')
    # handle scale from manifest
    if filename.endswith('.png'):
        srcfile = os.path.join(src, filename)
        if os.path.exists(srcfile):
            destname = f"icon_{os.path.splitext(filename)[0]}.png"
            if image.get('scale') == '2x':
                destname = f"icon_{os.path.splitext(filename)[0]}@2x.png"
            dst = os.path.join(out, destname)
            shutil.copyfile(srcfile, dst)

PYTHON

    iconutil -c icns "$TMP_ICONSET" -o "$ICON_DEST_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "⚠️ No se pudo generar icns con iconutil (iconset conversion)." 
    fi
    rm -rf "$TMP_ICONSET"
fi

# If icon already exists as .icns (alternativa directa)
if [ -f "icons/AppIcons/NativeTouch.icns" ]; then
    cp "icons/AppIcons/NativeTouch.icns" "$ICON_DEST_FILE"
fi

# Fallback: create from png appstore if still missing
if [ ! -f "$ICON_DEST_FILE" ] && [ -f "icons/AppIcons/appstore.png" ]; then
    echo "🖼️ Generando icns de icono PNG fallback con sips..."
    TMP_ICONSET="/tmp/NativeTouch.iconset"
    rm -rf "$TMP_ICONSET"
    mkdir -p "$TMP_ICONSET"

    sizes=(16 32 64 128 256 512)
    for s in "${sizes[@]}"; do
        sips -z $s $s "icons/AppIcons/appstore.png" --out "$TMP_ICONSET/icon_${s}x${s}.png" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "⚠️ sips falló en tamaño $s";
        fi
    done

    # 2x versions for high resolution
    for s in 16 32 64 128 256; do
        let sx=$s*2
        sips -z $sx $sx "icons/AppIcons/appstore.png" --out "$TMP_ICONSET/icon_${s}x${s}@2x.png" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "⚠️ sips falló en tamaño @2x $sx";
        fi
    done

    iconutil -c icns "$TMP_ICONSET" -o "$ICON_DEST_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "⚠️ No se pudo generar NativeTouch.icns desde PNG fallback."
    fi
    rm -rf "$TMP_ICONSET"
fi

echo "⚙️ Compilando $SOURCE_FILES..."
swiftc $SOURCE_FILES -o "$APP_NAME/Contents/MacOS/$EXECUTABLE_NAME" -framework Cocoa -framework ApplicationServices -framework IOKit

if [ $? -ne 0 ]; then
    echo "❌ Error durante la compilación."
    exit 1
fi

echo "📝 Generando Info.plist..."
cat > "$APP_NAME/Contents/Info.plist" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>io.xperiments.nativetouch</string>
    <key>CFBundleName</key>
    <string>NativeTouch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>NativeTouch</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>Input Monitoring is required to capture system mouse events and prevent text selection bugs across screens.</string>
</dict>
</plist>
PLIST_EOF

echo "🔄 Registrando aplicación en LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_NAME"

echo "🔑 Firmando la aplicación ad-hoc..."
codesign --force --deep --sign - "$APP_NAME"

echo "🧹 Reseteando TODA la base de datos TCC de permisos antiguos para forzar la ventana interactiva..."
tccutil reset All io.xperiments.nativetouch 2>/dev/null

echo "✅ Build completado con éxito. Aplicación generada en: $APP_NAME"
echo ""
echo "=========================================================================="
echo "⚠️  IMPORTANTE:"
echo "1. Ejecuta la aplicación con: open NativeTouch.app"
echo "2. NUNCA la abras con 'sudo'."
echo "3. MacOS te saltará dos ventanas emergentes para conceder permisos."
echo "4. Tras dárselos, es posible que el sistema te pida 'Salir y volver a intentar'."
echo "=========================================================================="

killall "NativeTouch" 2>/dev/null
open "$APP_NAME"