#!/bin/bash

function assert_dir_has_file() {

	TESTDIR=$1
	FILENAME=$2

	# look for other files as a sanity test

	echo -n "Looking for file $TESTDIR$FILENAME... "
	if [[ ! -f $TESTDIR/$FILENAME ]]
	then 
		echo "Can't find '$FILENAME' file! Exiting."
		exit 1
	fi

	echo "Found it!"

}

function runprint {

	echo -e "  Student answer: $@"

}


function user_in_group() {
# user_in_group -- determine whether a user is in some group
# usage: user_in_group username groupname question-mode
#
# username: the user's name, e.g., 'larry'
# groupname: the group name in question, e.g., 'wheel'
# question-mode: the question number for the spreadsheet, e.g., Q
#                or "quiet" to suppress output if using function
#				 for boolean output
#
# output: prints evidence for non-membership and sets GRP_BOOL to 
#         'in' or 'out' depending on truth value.
#
#         if question-mode is 'quiet' does not print output.
# 
# there are two ways that a user can be in a group. Using 'emp' and 'larry' as
# examples:
#
# 1. the 'emp' line in group contains "larry"
#
# 2. "larry" has the 'emp' group number as their primary group in passwd (this
# will be the case if students created the account with adduser and the
# '--ingroup' option).
#
# We need to test both possibilities.

	USR=$1 # what user are we testing
	GRP=$2 # what group should they be in?
	QNUM=$3 # what question number is this in spreadsheet?
	        # OR enter 'quiet' to suppress messages (for boolean)

	# does this group even exist?
	if ! grep -E "^$GRP" group &> /dev/null
	then
		echo "$QNUM: group $GRP doesn't exist!"
		return
	fi

	GRP_BOOL="" # a boolean set to 'in' or 'out' for later reference
	GRP_PROB="" # a string that describes the evidence

	# get the group number for emp
	GRPID=$(grep -E "^$GRP" group | sed -r "s/^$GRP:x:([^:]+):.*/\1/") >> $LOG

	# test case #1 -- user is listed in group
	if ! grep "^$GRP" group | grep $USR >> $LOG
	then
		GRP_PROB="'$USR' not in group '$GRP'" 
		
		# testing case #2
		PRIGROUP=$(grep -E "^$USR" passwd | sed -r "s/$USR:x:[^:]+:([^:]+):.*/\1/")

		if [[ $GRPID != $PRIGROUP ]]
		then

			if [[ $QNUM != "quiet" ]]
			then
				GRP_PROB="$GRP_PROB; $GRPID isn't '$USR's primary group (it's $PRIGROUP)"
				echo "$QNUM: '$USR' not in group '$GRP' (primary or secondary)."
				echo "  $GRP_PROB"
				runprint $(grep ^$GRP group)
				runprint $(grep ^$USR passwd)
			fi

			GRP_BOOL="out" # $USR is not in $GRP
			return

		fi
	fi

	GRP_BOOL="in" # $USR is in $GRP

}

function usage() {

cat <<EOR
permtest.sh -- test permissions for the assignment
--------------------------------------------------
usage: sudo ./permtest.sh [-n TESTNUM] [-d DIR] [-r]

Options:
	-n TESTNNUM	the single test to run (otherwise run all tests)
	-d DIR		the directory to grade (otherwise use /)
	-g 			print feedback and scores for all tests; do not quit on error

The program will quit on the first error unless the -g option is used.

EOR
exit

}


LOG="/tmp/permtestlog"
TESTNUM=0
DIR=""


while getopts "dn" o; do
	case "${o}" in
		n)
			TESTNUM=${OPTARG}
			;;
		d)
			DIR=${OPTARG}
			;;
		*)
			usage
			;;

	esac
done

# determine if we are on a live machine or in an "unzipped tarball"
# if we are in a tarball, fix up the directory structure to look like
# a live machine.

if [[ $DIR ]]
then

	echo "DIR is '$DIR'"
	# assert /etc/passwd exists
	if [[ ! -f /etc/passwd ]]
	then
		echo "/etc/passwd doesn't exist. Did you forget to specify a dir with -d?"
		exit 1
	fi

else
	echo "We are grading an unzipped tarball."

	# if this is a tarball of a submission, it will have a 'passwd' file
	# corresponding to the /etc/passwd file on the experimental node. However,
	# depending on how the tarball was created, it could be several layers deep.
	# Let's try to find the right subdirectory.

	TESTDIR=$(find $DIR 2> /dev/null | grep passwd)  # look for a passwd file
	TESTDIR=${TESTDIR%%passwd}			# trim 'passwd' from dir
	TESTDIR=${TESTDIR%%etc/}			# trim 'etc/' from end if exists
	DIR=$TESTDIR
	
	if ! pushd $DIR >> $LOG
	then
		echo "Fatal: Couldn't pushd to $DIR?"
		exit 1
	fi

	# check to see if we have "fixed" this tarball to look like a real filesystem
	if [[ ! -f .permtest_fixed ]]
	then

		for TESTFILE in passwd group sudoers shadow permissions-answers.txt
		do
			assert_dir_has_file . $TESTFILE
		done

		echo "I'm satisfied we found the right directory. Buckle up."

		echo "Repairing this tarball to look like a real filesystem."

		sudo mkdir etc
		
		for f in group passwd shadow sudoers
		do
			if ! sudo mv $f etc/ 
			then
				echo "Fatal: Couldn't move $f to etc/ !"
				exit 1
			fi
		done

		sudo touch .permtest_fixed # create stamp so we avoid this next time
	

		echo "Looking at entries in $DIR..."
		echo


	else
		echo "User specified a directory, but this directory has already been 'fixed'."
		echo "Continuing..."
	fi

fi

echo "quit"
exit

# /home should be owner root and user wheel (i.e., root:wheel); but the system
# we are grading on may not have a wheel group. even if it did, it is probably
# not the same numeric GID as on the student's node (and thus their
# submission). So, we need to figure out what group id wheel had on the
# student's node, and then find out what group has that group id on this
# system. That name is what will show up when we check it out.

# get the groupid for wheel and tps from the student's submission
EMPGRP="emp"
EMPID=$(grep -E "^$EMPGRP" group | sed -r "s/^$EMPGRP:x:([^:]+):.*/\1/") >> $LOG
echo "$EMPGRP's submitted GID is '$EMPID'... "

# if there is a group with that ID on this system, it will have a different name
# we'll need to know that name for grading purposes. If there is no such group,
# we'll need to use the ID instead.

if grep -E ".+:x:$EMPID:" /etc/group
then
	# get the LOCAL group name matching that group ID on the current system:
	EMPNAME=$(grep ".+:x:$EMPID:" /etc/group | sed -r "s/([^:]+):.*/\1/") >> $LOG
else
	# no such group -- just use the number
	echo "There is no local '$EMPGRP' group on this system. "
	EMPGRP=$EMPID
fi

echo "The local name for 'wheel' is '$EMPGRP'."
echo 




# do the same thing for the wheel group
WHEELID=$(grep -E "^wheel" group | sed -r "s/^wheel:x:([^:]+):.*/\1/") >> $LOG
echo "wheel's submitted GID is '$WHEELID'... "

if grep -E ".+:x:$WHEELID:" /etc/group
then
	# get the LOCAL group name matching that group ID on the current system:
	WHEEL=$(grep ".+:x:$WHEELID:" /etc/group | sed -r "s/([^:]+):.*/\1/") >> $LOG
else
	# no such group -- just use the number
	echo "There is no local 'wheel' group on this system. "
	WHEEL=$WHEELID
fi

echo "The local name for 'wheel' is '$WHEEL'."
echo 

# we need this information for the tps user just like for wheel group above.
# it's unlikely there's a tps user, but hey... it's not wrong to check.
TPSID=$(grep -E "^tps" passwd | sed -r "s/^tps:x:([^:]+):.*/\1/")
echo "tps's submitted user ID is '$TPSID'... "

if grep -E "^tps" /etc/passwd
then
	TPS=$(grep :$TPSID: /etc/passwd | sed -r 's/tps:x:([^:]+):.*/\1/')
else
	echo "There is no local user 'tps'... "
	TPS=$TPSID
fi
echo "The local name for 'tps' is '$TPS'"
echo

echo "Looking for flaws in submission (only reporting errors)..."
echo

# students must create admins directory
if ! ls -al | grep admins >> $LOG
then
	echo "D: no /admins directory."
fi

# ownership of admin homedirs should be ken:ken, etc.
for OLDBIE in ken
do

	# we need the UIDs for ken:
	ADMU=$(grep -E "^$OLDBIE" passwd | sed -r "s/^$OLDBIE:x:([^:]+):.*$/\1/")
	ADMG=$(grep -E "^$OLDBIE" group | sed -r "s/^$OLDBIE:x:([^:]+):.*$/\1/")

	if ! ls -n admins | grep $OLDBIE | grep -E "$ADMU.+$ADMG" >> $LOG
	then
		echo "E: $OLDBIE home ownership not correct, should be '$ADMU $ADMG'"
		runprint $(ls -n admins | grep $OLDBIE)
	fi
	
	# and permissions should be drwxrwsr-x
	if ! ls -al admins | grep $OLDBIE | grep -E "drwxrwsr-x" >> $LOG
	then
		echo "E: $OLDBIE home perms not correct (s.b. drwxrwsr-x)"
		runprint $(ls -al admins | grep $OLDBIE)
	fi


done

# does the home directory exist?
if [[ ! -d /home ]]
then
	echo "F: Directory /home does not exist!!!"
fi

# wheel should be the group of the home directory
if ! ls -al | grep home | grep -E "root.+$WHEEL" >> $LOG
then
	echo "F: home user:group not correct (s.b. root:$WHEEL):"
	runprint $(ls -al | grep home)
fi

# permissions on home should be rwxrwx--x
if ! ls -al | grep home | grep -E "(rwxrwx--x|---rwx--x)" >> $LOG
then
	echo "G: /home permissions are not correct (s.b. 0771/rwxrwx--x or 0071/---rwx--x)"
	runprint $(ls -al | grep home)
fi

# homedirs in /home should be set 0750
for EMP in larry moe curly
do

	if ! ls -al home | grep $EMP | grep "drwxr-x---" >> $LOG
	then
		echo "H: homedir /home/$EMP has incorrect permissions (should be 0750/drwxr-x---)"
		runprint $(ls -al home | grep $EMP)
	fi

done


# there must be a ballots dir
if ! ls -al | grep ballots >> $LOG
then
	echo "I: no ballots box"
	runprint $(ls -al | grep ballots)
fi

# ownership of ballots directory
if ! ls -al | grep ballots | grep -E "root.+$WHEEL" >> $LOG
then
 	echo "J: ballots user:group is incorrect (s.b. root:$WHEEL)"
	runprint $(ls -al | grep ballots)
fi

# and its permissions should be drwx----wx
if ! ls -al | grep ballots | grep -E "(drwx----wx|d-------wx)" >> $LOG
then
	echo "K: ballots perms not correct (s.b. 0703/drwx----wx or 0003/d-------wx)"
	runprint $(ls -al | grep ballots)
fi

# tps reports directory must exist.
if ! ls -al | grep tpsreports >> $LOG
then
	echo "L: no tpsreports dir"
fi

# there should be a special 'tps' user
#if ! grep -E "^tps" group | sed -r "s/^tps:x:(.+):.+/\1/" >> $LOG
if ! grep -E "^tps" group 
then
	echo "M: 'tps' user does not exist!"
fi

# the tpsreports directory should be owned tps with group wheel
if ! ls -al | grep tpsreports | grep -E "$TPS.+$WHEEL" >> $LOG
then
	echo "N: tpsreports ownership not correct, should be '$TPS $WHEEL'"
	runprint $(ls -al | grep tpsreports)
fi



# the permissions mode on tpsreports should be dwrxrws--T
if ! ls -al | grep tpsreports | grep -E 'drwxrws--T' >> $LOG
then
	echo "O: tpsreports perms not correct (s.b. 3770/dwrxrws--T):"
	runprint $(ls -al | grep tpsreports)
fi

# larry, moe, and curly should be in the emp group
user_in_group "larry" "emp" "P"
user_in_group "moe" "emp" "P"
user_in_group "curly" "emp" "P"
# the last letter above (e.g., P) indicates the question column for grading

# admins should NOT be in the emp group
GNAME="emp"
for UNAME in ken 
do 
	user_in_group "$UNAME" "$GNAME" "quiet"
	if [[ $GRP_BOOL == "in" ]]
	then
		echo "Q: $UNAME is in $GNAME but shouldn't be!"
		runprint $(grep ^$GNAME group)
		runprint $(grep ^$UNAME passwd)
	fi
done

# ken should be in wheel
user_in_group "ken" "wheel" "R"

# emps should NOT be in the wheel group
echo "Check to see if emps are in wheel (no news is good news)..."
GNAME="wheel"
for UNAME in larry moe curly
do 
	user_in_group "$UNAME" "$GNAME" "quiet"
	if [[ $GRP_BOOL == "in" ]]
	then
		echo "S: $UNAME is in $GNAME but shouldn't be!"
		runprint $(grep ^$GNAME group)
		runprint $(grep ^$UNAME passwd)
	fi
done

echo "Check admin groups memberships..."
# there should be a 'wheel' group
for GROOP in ken dmr bwk
do
	if ! grep -E "^$GROOP" group 
	then
		echo "S: group '$GROOP' group does not exist!"
	fi
done

# admin group special memberships

if ! grep ^ken group | grep bwk | grep dmr | grep larry  >> $LOG
then
	echo "S: ken group should include bwk, dmr, larry (any order) but had:"
	runprint $(grep ^ken group)
fi

if ! grep ^dmr group | grep curly | grep ken | grep bwk  >> $LOG
then
	echo "S: dmr group should include curly, ken, bwk (any order) but had:"
	runprint $(grep ^dmr group)
fi

if ! grep ^bwk group | grep moe | grep dmr | grep ken  >> $LOG
then
	echo "S: bwk group should include moe, dmr, ken (any order) but had:"
	runprint $(grep ^bwk group)
fi


echo "Done."
popd >> $LOG
