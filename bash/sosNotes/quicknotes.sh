#!/bin/bash

nota="$HOME/Notes/00_Notas/quickNotes/nota-$(date +%Y-%m-%d).md"

[[ ! -f $nota ]] && echo "# Notas: $(date +%Y-%m-%d)" > $nota

nvim -c "norm Go" \
		-c "norm Go## $(date +%H:%M)" \
		-c "norm G2o" \
		-c "norm zz"\
		-c "startinsert" $nota
