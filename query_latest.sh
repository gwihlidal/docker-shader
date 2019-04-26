echo "Latest DXC_COMMIT"
git ls-remote https://github.com/gwihlidal/DirectXShaderCompiler.git HEAD | awk '{ print $1}'
echo ""

echo "Latest SHADERC_REPO"
git ls-remote https://github.com/google/shaderc.git HEAD | awk '{ print $1}'
echo ""

echo "Latest GOOGLE_TEST_REPO"
git ls-remote https://github.com/google/googletest.git HEAD | awk '{ print $1}'
echo ""

echo "Latest GLSLANG_REPO"
git ls-remote https://github.com/KhronosGroup/glslang.git HEAD | awk '{ print $1}'
echo ""

echo "Latest SPV_TOOLS_REPO"
git ls-remote https://github.com/KhronosGroup/SPIRV-Tools.git HEAD | awk '{ print $1}'
echo ""

echo "Latest SPV_HEADERS_REPO"
git ls-remote https://github.com/KhronosGroup/SPIRV-Headers.git HEAD | awk '{ print $1}'
echo ""

echo "Latest RE2_REPO"
git ls-remote https://github.com/google/re2.git HEAD | awk '{ print $1}'
echo ""

echo "Latest EFFCEE_REPO"
git ls-remote https://github.com/google/effcee.git HEAD | awk '{ print $1}'
echo ""

echo "Latest WINE_REPO"
git ls-remote https://github.com/wine-mirror/wine.git HEAD | awk '{ print $1}'
echo ""

echo "Latest SMOLV_REPO"
git ls-remote https://github.com/aras-p/smol-v.git HEAD | awk '{ print $1}'
echo ""
