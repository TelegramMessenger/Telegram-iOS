DIR="$(pwd)"
cd "$HOME/build/buck"
buck-out/gen/programs/buck.pex build buck
cd "$DIR"
