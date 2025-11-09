set -e

rm -rf dist

PROJECT=$(basename $(pwd))
VERSION=$(git describe --abbrev=0 --tags)
ZIGVERSION=$(zig version)

echo "Preparing release for $PROJECT $VERSION"
echo "Building using zig version $(zig version)"

zig test src/index.zig

mkdir dist
cd dist

FLAGS=-Drelease-fast
TARGET=x86_64-linux

NAME=2048
zig build-exe ../$NAME.zig $FLAGS -target $TARGET
tar -czvf "$NAME-$VERSION-$TARGET.tar.gz" $NAME
rm $NAME

NAME=pathtracer
zig build-exe ../$NAME.zig $FLAGS -target $TARGET
tar -czvf "$NAME-$VERSION-$TARGET.tar.gz" $NAME
rm $NAME

NAME=xortexture
zig build-exe ../$NAME.zig $FLAGS -target $TARGET
tar -czvf "$NAME-$VERSION-$TARGET.tar.gz" $NAME
rm $NAME

FLAGS=-Drelease-fast
TARGET=x86_64-windows

NAME=2048
zig build-exe ../$NAME.zig -Drelease-fast -target $TARGET
zip "$NAME-$VERSION-$TARGET.zip" $NAME.exe
rm $NAME.exe $NAME.pdb

NAME=pathtracer
zig build-exe ../$NAME.zig -Drelease-fast -target $TARGET
zip "$NAME-$VERSION-$TARGET.zip" $NAME.exe
rm $NAME.exe $NAME.pdb

NAME=xortexture
zig build-exe ../$NAME.zig -Drelease-fast -target $TARGET
zip "$NAME-$VERSION-$TARGET.zip" $NAME.exe
rm $NAME.exe $NAME.pdb

cp -r ../src "$PROJECT"
echo $VERSION >"$PROJECT/version"
echo $ZIGVERSION >"$PROJECT/zigversion"

zip -r "$PROJECT-$VERSION.zip" $PROJECT
tar -czvf "$PROJECT-$VERSION.tar.gz" $PROJECT

rm -rf $PROJECT
