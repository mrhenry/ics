#!/bin/bash

source "names.sh";

(
	echo "package ics";
	echo;
	echo "// File automatically generated with ./genParams.sh";
	echo;
	echo "import (";
	echo "	\"strings\"";
	echo;
	echo "	\"github.com/MJKWoolnough/parser\"";
	echo ")";
	echo;
	{
		while read line; do
			keyword="$(echo "$line" | cut -d'=' -f1)";
			type="$(getName "$keyword")";
			values="$(echo "$line" | cut -d'=' -f2)";

			echo -n "type $type ";

			declare multiple=false;
			declare freeChoice=false;
			declare doubleQuote=false;
			declare regex="";
			declare vType="";
			declare string=false;
			declare -a choices=();
			fc="${values:0:1}";
			if [ "$fc" = "*" ]; then
				echo -n "[]";
				multiple=true
				values="${values:1}";
				fc="${values:0:1}";
			fi;
			if [ "$fc" = "?" ]; then
				freeChoice=true
				values="${values:1}";
				fc="${values:0:1}";
			fi;
			if [ "$fc" = '"' ]; then
				doubleQuote=true;
				values="${values:1}";
				fc="${values:0:1}";
				string=true;
			elif [ "$fc" = "'" ]; then
				values="${values:1}";
				string=true;
				fc="${values:0:1}";
			elif [ "$fc" = "~" ]; then
				regex="${values:1}";
				string=true;
				fc="${values:0:1}";
			fi;
			if [ "$fc" = "!" ]; then
				values="${values:1}";
				echo "$values";
				vType="$values";
			elif $string; then
				echo "string";
			else
				if $freeChoice; then
					choices=( $(echo "Unknown|$values" | tr "|" " ") );
				else
					choices=( $(echo "$values" | tr "|" " ") );
				fi;
				case ${#choices[@]} in
				1)
					echo "struct{}";;
				*)
					echo "uint8";
					echo;
					echo "const (";
					declare first=true;
					declare longest=0;
					for choice in ${choices[@]}; do
						declare c="$(getName "$choice")";
						declare l="${#c}";
						if [ $l -gt $longest ]; then
							longest=$l;
						fi;
					done;
					for choice in ${choices[@]};do
						echo -n "	$type$(getName "$choice")";
						if $first; then
							if [ ${#choice} -lt $longest ]; then
								for i in $(seq $(( $longest - ${#choice} ))); do
									echo -n " ";
								done;
							fi;
							echo -n " $type = iota";
							first=false;
						fi;
						echo;
					done;
					echo ")";
				esac;
				choices=( $(echo "$values" | tr "|" " ") );
			fi;
			echo;

			# decoder

			echo "func (t *$type) decode(vs []parser.Token) error {";
			declare indent="";
			declare vName="vs[0]";
			if $multiple; then
				echo "	for _, v := range vs {";
				indent="	";
				vName="v";
			else
				echo "	if len(vs) != 1 {";
				echo "		return ErrInvalidParam";
				echo "	}";
			fi;
			if $doubleQuote; then
				echo "$indent	if ${vName}.Type != tokenParamQuotedValue {";
				echo "$indent		return ErrInvalidParam";
				echo "$indent	}";
				echo "$indent	var p Text";
				echo "$indent	if err := p.encode(nil, ${vName}.Data); err != nil {";
				echo "$indent		return err";
				echo "$indent	}";
				echo "$indent	${vName}.Data = string(p)";
			fi;
			if [ ! -z "$vType" ]; then
				echo "$indent	var q $vType";
				echo "$indent	if err := q.decode(nil, ${vName}.Data); err != nil {";
				echo "$indent		return err";
				echo "$indent	}";
				if $multiple; then
					echo "		*t = append(*t, q)";
				else
					echo "	*t = $type(q)";
				fi;
			elif [ ${#choices[@]} -eq 1 ]; then
				echo "	if strings.ToUpper(${vName}.Data) != \"${choices[0]}\" {";
				echo "		return ErrInvalidParam";
				echo "	}";
			elif [ ${#choices[@]} -gt 1 ]; then
				echo "$indent	switch strings.ToUpper(${vName}.Data) {";
				for choice in ${choices[@]}; do
					echo "$indent	case \"$choice\":";
					if $multiple; then
						echo "		*t = append(*t, $(getName "$choice")";
					else
						echo "		*t = $type$(getName "$choice")";
					fi;
				done;
				echo "$indent	default:";
				if $freeChoice; then
					if $multiple; then
						echo "		*t = append(*t, {$type}Unknown)";
					else
						echo "		*t = ${type}Unknown";
					fi;
				else
					echo "$indent		return ErrInvalidParam";
				fi;
				echo "$indent	}";
			else
				if [ -z "$regex" ]; then
					if $multiple; then
						echo "		*t = append(*t, ${vName}.Data)";
					else
						echo "	*t = $type(${vName}.Data)";
					fi;
				else
					echo "#REGEX";
				fi;
			fi;
			
			if $multiple; then
				echo "	}";
			fi;
			echo "	return nil";
			echo "}";
			echo;

			#encoder

			echo "func (t *$type) encode(w writer) {";
			echo "}";
			echo;
		done;
	} < params.gen
) #> params.go
