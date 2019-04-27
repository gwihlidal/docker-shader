echo "Latest DXC_COMMIT"
git ls-remote https://github.com/gwihlidal/DirectXShaderCompiler.git HEAD | awk '{ print $1}'
echo ""

echo "Latest SHADERC_REPO"
git ls-remote https://github.com/google/shaderc.git HEAD | awk '{ print $1}'
echo ""

echo "Latest WINE_REPO"
git ls-remote https://github.com/wine-mirror/wine.git HEAD | awk '{ print $1}'
echo ""

echo "Latest SMOLV_REPO"
git ls-remote https://github.com/aras-p/smol-v.git HEAD | awk '{ print $1}'
echo ""
