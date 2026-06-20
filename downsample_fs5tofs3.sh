#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 processed_csv outdir" >&2
  exit 1
fi

CSV="$1"
OUTDIR="$2"

mkdir -p "$OUTDIR"

export SUBJECTS_DIR=/var/datasets/freesurfer  

# Count subjects 
TOTAL=$(( $(wc -l < "$CSV") - 1 ))
if [ "$TOTAL" -le 0 ]; then
  echo "No data rows found in $CSV" >&2
  exit 1
fi

echo "[$(date)] Starting fsaverage5 -> fsaverage3 downsampling for $TOTAL subjects" >&2

i=0

tail -n +2 "$CSV" | while IFS=, read -r subj path_L_fs5 path_R_fs5 _rest; do
  i=$((i+1))

  if [ -z "$subj" ]; then
    echo "Row $i has empty subject_id, skipping" >&2
    continue
  fi
  if [ ! -f "$path_L_fs5" ] || [ ! -f "$path_R_fs5" ]; then
    echo "[$(date)] WARN: Missing fs5 files for $subj, skipping" >&2
    continue
  fi

  tmpdir=$(mktemp -d)
  subj_outdir="$OUTDIR/$subj"
  mkdir -p "$subj_outdir"

  # ---- Left hemisphere ----
  mri_convert "$path_L_fs5" "$tmpdir/lh.fs5.mgz"

  mri_surf2surf \
    --srcsubject fsaverage5 \
    --trgsubject fsaverage3 \
    --hemi lh \
    --sval "$tmpdir/lh.fs5.mgz" \
    --tval "$subj_outdir/${subj}_task-rest_hemi-L_space-fsaverage3_bold.mgz"

  # Optional: convert back to GIFTI func
  mri_convert \
    "$subj_outdir/${subj}_task-rest_hemi-L_space-fsaverage3_bold.mgz" \
    "$subj_outdir/${subj}_task-rest_hemi-L_space-fsaverage3_bold.func.gii"

  # ---- Right hemisphere ----
  mri_convert "$path_R_fs5" "$tmpdir/rh.fs5.mgz"

  mri_surf2surf \
    --srcsubject fsaverage5 \
    --trgsubject fsaverage3 \
    --hemi rh \
    --sval "$tmpdir/rh.fs5.mgz" \
    --tval "$subj_outdir/${subj}_task-rest_hemi-R_space-fsaverage3_bold.mgz"

  mri_convert \
    "$subj_outdir/${subj}_task-rest_hemi-R_space-fsaverage3_bold.mgz" \
    "$subj_outdir/${subj}_task-rest_hemi-R_space-fsaverage3_bold.func.gii"

  rm -rf "$tmpdir"

  # Progress logging (to stderr)
  pct=$(( 100 * i / TOTAL ))
  echo "[$(date)] Processed $subj ($i/$TOTAL, ${pct}%)" >&2
done

echo "[$(date)] Finished downsampling all subjects in $CSV" >&2
