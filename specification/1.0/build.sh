#!/usr/bin/env bash
# Build the Dryad Language Specification, Edition 1.0.
#
# Inputs : src/*.md (concatenated in lexicographic order)
# Outputs: dryad-specification.html
#          dryad-specification.tex
#          dryad-specification.pdf
#
# Requirements: pandoc >= 3.1 and tectonic (or any XeLaTeX engine).
# Install (no sudo):
#   pandoc   https://github.com/jgm/pandoc/releases
#   tectonic https://github.com/tectonic-typesetting/tectonic/releases
set -euo pipefail
cd "$(dirname "$0")"

PANDOC="${PANDOC:-pandoc}"
PDF_ENGINE="${PDF_ENGINE:-tectonic}"

command -v "$PANDOC" >/dev/null 2>&1 || {
    echo "error: pandoc not found (set PANDOC=... or add it to PATH)" >&2
    exit 1
}
command -v "$PDF_ENGINE" >/dev/null 2>&1 || {
    echo "error: PDF engine '$PDF_ENGINE' not found (set PDF_ENGINE=...)" >&2
    exit 1
}

TMPDIR_BUILD="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BUILD"' EXIT

# Concatenate the clauses in numeric order. Each file starts with a top-level
# heading carrying its own fixed clause number.
mapfile -t SOURCES < <(find src -maxdepth 1 -name '*.md' | LC_ALL=C sort)
: > "$TMPDIR_BUILD/spec.md"
for source in "${SOURCES[@]}"; do
    cat "$source" >> "$TMPDIR_BUILD/spec.md"
    printf '\n\n' >> "$TMPDIR_BUILD/spec.md"
done

COMMON=(
    --from markdown+smart+fenced_divs+pipe_tables+footnotes+task_lists
    --standalone
    --toc
    --toc-depth=3
)

# ---------------------------------------------------------------------------
# HTML edition
# ---------------------------------------------------------------------------
"$PANDOC" "$TMPDIR_BUILD/spec.md" \
    "${COMMON[@]}" \
    --template=assets/spec.html5 \
    --css=assets/spec.css \
    --metadata=lang:en \
    -o dryad-specification.html

# ---------------------------------------------------------------------------
# LaTeX source (committed as a reviewable artifact)
# ---------------------------------------------------------------------------
"$PANDOC" "$TMPDIR_BUILD/spec.md" \
    "${COMMON[@]}" \
    --include-in-header=assets/preamble.tex \
    --variable=mainfont:"Liberation Serif" \
    --variable=monofont:"DejaVu Sans Mono" \
    --variable=monofontoptions:Scale=0.82 \
    --variable=fontsize:11pt \
    --variable=papersize:a4 \
    --variable=geometry:margin=2.4cm \
    --variable=colorlinks:true \
    --variable=linkcolor:dryadgreen \
    --variable=urlcolor:dryadgreen \
    --variable=toccolor:black \
    -t latex \
    -o dryad-specification.tex

# ---------------------------------------------------------------------------
# PDF edition
# ---------------------------------------------------------------------------
"$PANDOC" "$TMPDIR_BUILD/spec.md" \
    "${COMMON[@]}" \
    --include-in-header=assets/preamble.tex \
    --pdf-engine="$PDF_ENGINE" \
    --variable=mainfont:"Liberation Serif" \
    --variable=monofont:"DejaVu Sans Mono" \
    --variable=monofontoptions:Scale=0.82 \
    --variable=fontsize:11pt \
    --variable=papersize:a4 \
    --variable=geometry:margin=2.4cm \
    --variable=colorlinks:true \
    --variable=linkcolor:dryadgreen \
    --variable=urlcolor:dryadgreen \
    --variable=toccolor:black \
    -o dryad-specification.pdf

echo "built:"
ls -lh dryad-specification.html dryad-specification.tex dryad-specification.pdf
