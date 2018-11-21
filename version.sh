#!/bin/dash

#Avenia Adrien - Marche Claire

#prints the correct usage of the script to standard error
print_synopsis() {
    echo "Usage : $0 <command> file [option]" >&2
    echo "where <command> can be: add checkout commit diff log revert rm" >&2
}

#adds first argument file under versionning and creates log file with date of addition
#shows error if file is already under versionning
add() {
    DIR=$(dirname $1)
    FILE=$(basename $1)
    if test -e "$DIR/.version/$FILE.latest"; then
        echo "File '$FILE' is already under versionning. Please use commit to commit new changes" >&2
        print_synopsis
        return 3
    else
        if test ! -d "$DIR/.version"; then 
            mkdir $DIR/.version
        fi
        cp $1 $DIR/.version/$FILE.1
        cp $1 $DIR/.version/$FILE.latest
		echo "$(date -R) Add to versionning" > $DIR/.version/$FILE.log
        echo "Added a new file under versionning : '$FILE'"
    fi
}

#removes first argument file from versionning after confirmation
#also removes .version if no other file is present inside
#shows error if file wasn't under versionning
remove() {
    DIR=$(dirname $1)
    FILE=$(basename $1)
    if test -e "$DIR/.version/$FILE.latest"; then
        REP=""
        while test "$REP" != "yes" && test "$REP" != "no"; do
            echo -n "Are you sure you want to delete '$FILE' from versionning ? (yes/no)"
            read REP
        done
        if test "$REP" = "yes"; then
            rm $DIR/.version/$FILE.*
            rmdir "$DIR/.version/" 2> /dev/null
            echo "'$FILE' isn't under versionning anymore"
        else
            echo "'$FILE' hasn't been removed from versionning"
        fi
    else
        echo "File '$FILE' isn't under versionning" >&2
        print_synopsis
        return 4
    fi
}

#commits the latest changes to the document in a patch as well as in the latest file
#also writes the third argument as a comment for the version in the log file
#shows error if file isn't under versionning or if there is no non-empty comment to be found as a third argument
commit() {
    DIR=$(dirname $1)
    FILE=$(basename $1)
    if test -e "$DIR/.version/$FILE.latest"; then
				if test -z "$2"; then
					echo "A non-empty comment needs to be added to the commit" >&2
					return 5
				fi
        NUM=1
        while test -e "$DIR/.version/$FILE.$NUM"; do
            NUM=$(($NUM + 1)) 
        done
        if test ! -z "$(diff -u $DIR/.version/$FILE.latest $1)"; then
            diff -u $DIR/.version/$FILE.latest $1 > $DIR/.version/$FILE.$NUM
            cp $1 $DIR/.version/$FILE.latest
			echo "$(date -R) $2" >> $DIR/.version/$FILE.log
            echo "Committed a new version : $NUM"
        else
            echo "The last change to '$FILE' has already been committed"
        fi
    else
        echo "File '$FILE' isn't under versionning. Please use the command add to add a new file to versionning before committing any changes" >&2
        print_synopsis
        return 6
    fi
}

#reverts first argument file back to the latest committed version without keeping any traces of the changes
#shows error if file isn't under versionning
revert() {
    DIR=$(dirname $1)
    FILE=$(basename $1)
    
    if test -e "$DIR/.version/$FILE.latest"; then
        cp $DIR/.version/$FILE.latest $1
        echo "Reverted to the latest version"
    else
        echo "File '$FILE' isn't under versionning. Please use the command add to add a new file to versionning" >&2
        return 7
    fi
}

#prints the difference between the latest committed file and the current version of the file to the standard exit
#shows error if file isn't under versionning
print_diff() {
    DIR=$(dirname $1)
    FILE=$(basename $1)
    
    if test -e "$DIR/.version/$FILE.latest"; then
        diff -u $DIR/.version/$FILE.latest $1
    else
        echo "File '$FILE' isn't under versionning. Please use the command add to add a new file to versionning" >&2
        return 8
    fi
}

#checks out the version of first argument file defined in the third argument in place of the current file
#shows error if file isn't under versionning
checkout() {
    DIR=$(dirname $1)
    FILE=$(basename $1)
    NUM=1
    while test -e "$DIR/.version/$FILE.$NUM"; do
        NUM=$(($NUM + 1)) 
    done
    if (echo $2 | grep -E "^[[:digit:]]+$" -q) && test $2 -ne 0 && test $2 -lt $NUM; then
        CURR_DIR=$(pwd) #Given that patch won't apply on files with ../ on their path, we must change the current directory
        cd $DIR
        cp .version/$FILE.1 $FILE
        NUM=2
        while test $NUM -le $2; do
            patch -u $FILE .version/$FILE.$NUM 1> /dev/null 2> /dev/null
            NUM=$(($NUM + 1))
        done
        cd $CURR_DIR
        echo "Check out version: $2"
    else
        echo "The number of the version isn't correct" >&2
        return 9
    fi
}

#prints the log file to the standard output with numbered lines
#shows error if file isn't under versionning
log() {
	DIR=$(dirname $1)
	FILE=$(basename $1)
	if test -e "$DIR/.version/$FILE.latest"; then
			sed = $DIR/.version/$FILE.log | sed 'N;s/\n/ : /'
	else
	    echo "File '$FILE' isn't under versionning. Please use the command add to add a new file to versionning" >&2
      return 10
	fi
}

if test $# -lt 2; then 
    echo "Wrong number of arguments" >&2
    print_synopsis
    return 1
fi

COM=$1

if test $COM = "ci"; then
	COM="commit"
else if test $COM = "co"; then
	COM="checkout"
fi
fi

if test $COM = "commit" || test $COM = "checkout"; then
    if test $# -ne 3; then
				if test $COM = "commit"; then        
					echo "Wrong number of arguments, there needs to be a comment to add to the commit" >&2
				else
					echo "Wrong number of arguments, there needs to be a version number to checkout" >&2
				fi
        print_synopsis
        return 1
    fi
else
    if test $# -ne 2; then
        echo "Wrong number of arguments"
        print_synopsis
        return 1
    fi
fi

if ! test -f $2; then
    echo "$2 does not exist or is not a file" >&2
    print_synopsis
    return 2
fi
    
case $COM in
    (add) 
        add $2
    ;;
    (checkout)
        checkout $2 $3
    ;;
    (commit)
        commit $2 "$3"
    ;;
    (diff)
        print_diff $2
    ;;
    (log)
    	log $2
    ;;
    (revert)
        revert $2
    ;;
    (rm)
        remove $2
    ;;
    
    (*)
        echo "Error! This command name does not exist: '$1'" >&2
        print_synopsis
        return 3
    ;;
esac
