#!/bin/bash
set -o pipefail
# -------------------------------------------------- Vars
declare conf_dir="$HOME/.config/sosNotes"
declare default_conf="$conf_dir/default.conf"
declare school_conf="$conf_dir/school.conf"
declare origin=$PWD
declare noted="$origin/.noted"
declare default=1
declare conf
declare templates_dir="$conf_dir/templates"
# programs
mkdir="/bin/mkdir"
ls="/bin/ls"
mv="/bin/mv" 
cp="/bin/cp"
rm="/bin/rm"
touch="/bin/touch"
ln="/bin/ln"
cat="/bin/cat"
#specific
editor="/bin/nvim"
pandoc="/bin/pandoc"
pacman="/bin/pacman"

findConf() {
	# Go to root of notes
	if [[ -f "$noted" ]]; then 
		local notado=$($cat $noted)
		[[ ! -z $notado ]]&& cd $notado
	fi
	# check if config
	declare -g local_conf_dir="$PWD/.confs"
	declare -g init_conf="$PWD/init.conf"
 	declare -g local_conf="$local_conf_dir/notes.conf"
 	declare -g inited="$local_conf_dir/inited"
	[[ -d $local_conf_dir ]] && conf=$local_conf || conf=$init_conf
}

checkDependencies() {
	# chek if pacman # Might change
	[[ ! -x $pacman ]] && echo "Esto usa pacman.." && helpNotes "depe"
	# check deps
	local dependecies=("pandoc" "pandoc-crossref" "texlive-core")
	for dep in ${dependecies[@]}; do
		$pacman -Q $dep &> /dev/null
		if [[ -z ${PIPESTATUS[0]} ]]; then 
			echo -e "Falta:\t${dep}"
			helpNotes "depe"
	fi
	done
	# check editor
	[[ -z $editor ]] && echo "Este programa usa nvim"
}

# -------------------------------------------------- Init
# config dir name dir & place to move to init dir
initDir() { # :dirsArrays to init :where to move to init
	local -n struct=$1
	local extradir
	local start=$PWD
	[[ ! -z $2 ]] && cd $2
	for i in "${struct[@]}" ; do
		local ext="${i##*_}"
		[[ ${#ext} -le 4 ]] && i="${i%_*}" 
		[[ ! -d $i ]] && $mkdir $i 
		case ${ext} in
			p) extradir="$i/p{1..$periodos}" ;;
			pw) extradir="$i/p{1..$periodos}/wip" ;;
			pi) extradir="$i/p{1..$periodos}/img" ;;
			pwi) extradir="$i/p{1..$periodos}/wip/img" ;;
			sub) initDir subDir $i ;;
		esac
		$mkdir -p $(eval echo $extradir) 2> /dev/null
	done
	cd $start
}
# Init conifgs previous to inicialization 
initConfig(){
	local dir
	[[ ! -z $school_mode ]] && dir="Materias" || dir="Directorios"
	if [[ -z $default ]]; then 
		capConf $dir "baseDir"
		capConf "Subdirectorios" "subDir"
		read -p "Numero de Periodos: " periodos
	else
		source $default_conf
		capConf $dir "baseDir" baseDir
		capConf "Subdirectorios" "subDir" subDir
	fi
	if [[ ! -z $school_mode ]]; then
		echo "school_mode=1" >> $conf
		source $conf 
		echo ${baseDir[@]}
		capKeyedConf baseDir "maestros"
	fi
	# periodos
	[[ -z $periodos ]] && periodos=1
	printf "%s\n" "periodos=$periodos" >> $conf
	# select default for notes
	if [[ -z $default_subdir ]]; then 
		local notasDefault
		read -r -p "¿Quieres selecionar un subdirectorio como predeterminado para las nuevas notas? [s/N]" notasDefault
		case $notasDefault in
			[yY]|[eE]|[sS])
				select i in ${subDir[@]}; do
					local ext="${i##*_}"
					[[ ${#ext} -le 4 ]] && i="${i%_*}" 
					echo "Selecccionaste: $i ($REPLY)" 
					echo "default_subdir=$i" >> $conf
					break;
				done
				;;
				*) echo 'OK';;
		esac
	else
		echo "default_subdir=$default_subdir" >> $conf
	fi
	local author
	read -p "Que nombre quires usar como autor: " author
	author="${author[@]}"
	echo "author=\"$author\"" >> $conf
	local authorNum
	read -r -p "¿Desea introducir un numero asociado al author? [s/N]" authorNum
	case $authorNum in
		[yY]|[sS]) 
			read -p "Numero: " authorNum
			echo "authorNum=$authorNum" >> $conf 
			;;
		*) echo 'OK';;
	esac
}
# add noted to all dirs
initNoted() {
	for i in * ; do
		if [[ -d $i ]]; then
			local start="$PWD"
			cd $i
			$touch ".noted"
			echo "$origin" > ".noted"
			initNoted
			cd "$start"
		fi
	done
}
# init function, to initialize
init() {
	# check 
	[[ -e $inited ]] && helpNotes "init"
	checkDependencies
	[[ ! -f ${conf} ]] && initConfig
	# load conf
	source $conf # bad way , but, easiest way 
	initDir baseDir
	$mkdir "$local_conf_dir" 2> /dev/null
	$mv "$conf" "$local_conf" 2> /dev/null
	$touch $inited
	initNoted
	if [[ ! -z $school_mode ]]; then 
		local link="$HOME/Periodo"
		$rm $link 2> /dev/null
		echo "link -> $link"
		$ln -s "$origin" "$link"
	fi
	echo "Finish"
	exit 0;
}

# -------------------------------------------------- Conf
# handle config call=edit|make
config() {
	if [[ -e $inited ]]; then 
		$editor $conf
	else
		initConfig
	fi
	exit 0
}
# capture array of Conf data into file
capConf() { # :outputUser :nameArray :default
	[[ ! -z $3 ]] && local -n def=$3
	local -a data
	local capture
	echo "Introducir $1 (Dejar en blanco para terminar)"
	while true; do
		read -p "${1::(-1)}: " capture
		capture="${capture[@]}"
		[[ -z $capture ]] && break
		data+=(${capture// /_})
	done
	data+=(${def[@]})
	echo "$2=( \\" >> $conf
	for i in ${data[@]}
	do
		printf "%s\n" "\"$i\" \\" >> $conf
	done
	echo ")" >> $conf
}
# capture a keyd array to confs
capKeyedConf() { # :keysArray :nameKeyedArray :defaults
	# [[ ! -z $3 ]] && local -n def=$3 # add defaults, not implemented yet
	local -a keys=$(cleanConf $1) subject
 	echo "Introduce $2" 
	echo "declare -A $2=( \\" >> $conf
	for i in ${keys[@]}; do
		read -p "Introduzca ${2::(-1)} para \"$i\": " subject
		subject="${subject[@]}"
		[[ -z $subject ]] && continue
		printf "%s\n" "[$i]=\"$subject\" \\" >> $conf
	done
	echo ")" >> $conf
}

# ------------------------------------------------ Notes
# clean the config arrau form _postfix 
cleanConf() {
	local -n array=$1
	local -a cleanArray
	for i in ${array[@]}; do
		local ext="${i##*_}"
		if [[ ${#ext} -le 4 ]]; then
			cleanArray+=("${i%_*}")
		else
			cleanArray+=("${i}")
		fi
	done
	echo ${cleanArray[@]}
}
# go to the dir for the note
selectDir() {
	local dirs=$(cleanConf $1)
	select i in ${dirs[@]}; do
		[[ $i == "." ]] && break
		i="$PWD/$i"
		cd $i
		echo $i
		if [[ ! -z $default_subdir && -d $default_subdir && ! -z $default ]]; then 
			cd $default_subdir
		fi
		local -a local_dirs=$($ls -d */) 
		local_dirs+=(".")
		selectDir local_dirs
		break
	done
}
# Create notes
newNote() {
	local name="${1//_/ }"
	local header="$templates_dir/general.yaml" 
	[[ ! -z $school_mode ]] && header="$templates_dir/school.yaml" 
	if [[ -f $inited ]];then
		local -a folder=$(selectDir baseDir)
		folder=($folder)
		cd ${folder[-1]}
		folder=${folder[0]##*/}
		folder=${folder//_/ }
	fi
	local file="$(date +%y%m%d)_${1// /_}.md"
	[[ ! -z $school_mode ]] && local profesor=${maestros["${folder// /_}"]}
	[[ ! -z "$asName" ]] && file=$asName
	# metadata to add as a header
	echo "creando $file en $PWD"
	if [[ -f $header && ! -e $file ]]; then # add header if exits, and do not overwrite
		local date=$(date|awk '{print $2" de "$3" del "$4}') 
		header=$($cat $header)
		header=$(eval echo "${header}")
		echo "$header" > $file
	fi
	$editor \
		-c "norm Go" \
		-c "norm o# " \
		-c "norm zz" \
		-c "startinsert" \
		$file
	exit 0
}
# quick notes
quickNotes() {
	# quick note script
	# nota="$HOME/Notes/00_Notas/quickNotes/nota-$(date +%Y-%m-%d).md"
 
	# [[ ! -f $nota ]] && echo "# Notas: $(date +%Y-%m-%d)" > $nota

	# $editor -c "norm Go" \
	# 		-c "norm Go## $(date +%H:%M)" \
	# 		-c "norm G2o" \
	# 		-c "norm zz"\
	# 		-c "startinsert" $nota
	echo "algo"
}

# pandoc utils (renderNote files)
# pandoc renderNote apunte
renderNote() {
	[[ -f $noted ]] && cd $origin
	local filename=$1
	[[ ! -f $filename ]] && echo "Archivo \"$filename\" no encontrado" && exit 1
	local name="${filename%.*}"
	name="${name#[0-9][0-9][0-1][0-9][0-3][0-9]_}"
	[[ ! -z "$asName" ]] && name=$asName
	# school config
	if [[ ! -z $school_mode ]]; then 
		unset default
		$cp "$templates_dir/bg_school.png" "./"
	fi
	if [[ -z $default ]]; then 
		$pandoc $filename --pdf-engine=xelatex \
			--filter pandoc-crossref \
			-o "${name}.pdf"
	else
		local title
		[[ ! -z "$asTitle" ]] && title=${asTitle//_/ } || title="${name//_/ }"
		$pandoc $filename --pdf-engine=xelatex \
			--filter pandoc-crossref \
			-o "${name}.pdf" \
			-V title="${title}" 
	fi
	# clean dir
	[[ ! -z $school_mode ]] && $rm "bg_school.png"
	exit 0
}

# --------------------------------------------------- err
helpNotes() { # error/help handler mucho texto
	local sep="\n++++++++++++++++++++++++++++++++++++++**********\n"
	local fast="notes [-ds][-i|init][-c|conf][-r FILE_TO_RENDER][-n NEW_FILE_NAME] -h help"
	local function="
$sep
Este programa tiene las siguientes funciones:
$sep
(inicio, se usan solas) \n
-i|init\tInicializar (configurar directorio de las notas) \n
-c|conf\tEditar la configuracion \n
--as=NAME Donde NAME es una variable opcional para forzar el nombre \n
--title=TITLE Donde TITLE es el titulo que se mostrara en el documento
$sep
(se pueden combinar)
-d\tSeleciona que no se usen los defaults al momento de inicializado\n
-s\tActiva el modo escuela\n
-S\tExplicitamente desactiva el modo escuela\n
-r\tGenera pdf apartir de una nota \n
-n\tCrea una nota \n
-h\tMuestra este mensaje
$sep
"
	case $1 in
		depe)
			echo "Falta dependencia"
			;;
		init)
			echo "Ya esta inicializado"
			;;
		conf)
			echo "No se encontro archivo de configuracion"
			config
			;;
		help)
			echo -e "$function"
			exit 0
			;;
		*)
			if [[ ! -e ${conf} ]]; then 
				echo -e "$sep\t\tNo Conf $sep"
			elif [[ $conf == $init_conf && -f $inited ]]; then
				echo -e "$sep\t\tNot init $sep" 
			fi
			;;
	esac
	echo -e "$fast"
	exit 1
}

# ------------------------------------------------ main 
findConf
[[ -f $inited ]] && source $conf # bad way , but, easiest way 
# Options selections
while getopts ':dsicr:n:h-:' OPT; do
	case "${OPT}" in
		-)
			case "${OPTARG}" in
				init) init ;;
				conf) config ;;
				as=*) asName="${OPTARG#as=}" ;;
				title=*) asTitle="${OPTARG#title=}" ;;
				debug) 
					# here goes whatever is debugging
					selectDir baseDir 
					;;
				*) echo "${OPTARG}" ;;
			esac
			;;
		d) unset default ;;
		s) 
			school_mode=1
			default_conf=$school_conf
			;;
		S) 
			unset school_mode
			default_conf=$school_conf
			;;
		i) init ;;
		c) config ;;
		r) renderNote $OPTARG ;;
		n) newNote "${OPTARG[@]}" ;;
		h) helpNotes "help";;
		?) helpNotes ;;
	esac
done
[[ -z $@ ]] && helpNotes 
