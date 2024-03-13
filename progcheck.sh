#!/usr/bin/env bash

# progress checker

TOTAL=0
STEP=0
SECTIONS=1

if [[ $UID != "0" ]]
then
	echo "This script must be run as root. Try again as root or using sudo, e.g.,"
	echo "sudo ./progcheck.sh"
	exit
fi

function group_exists()
{
	# returns true if exists
	getent group $1 &> /dev/null
}

function user_exists()
{
	USERNAME=$1
	id $USERNAME &> /dev/null
}

function file_exists()
{
	FILENAME=$1
	[[ -f $FILENAME ]]

}

function dir_exists()
{
	FILENAME=$1
	[[ -d $FILENAME ]]
}

function path_has_modebit ()
{
	# returns true if permissions grep pattern matches for file
	MYPATH=$1
	MODEGREP=$2

	if [[ -d $MYPATH ]]
	then
		# this path is a directory, so get just its line
		PATHLINE=$(ls -al $MYPATH | grep -E "[[:space:]]\.$")
	else
		PATHLINE=$(ls -al $MYPATH)

	fi

	# returns true on a match, else false
	grep  -E "$MODEGREP" <<< $PATHLINE &> /dev/null

}

function test_path_owner ()
{
	MYPATH=$1
	OWNER=$2

	# returns true on a match, else false
	ls -al $MYPATH | grep -E "^..........[.+@]?[[:space:]]+[[:digit:]]+[[:space:]]+$OWNER" &> /dev/null

}

function test_path_group ()
{
	MYPATH=$1
	GROUP=$2

	# returns true on a match else false
	ls -al $MYPATH | grep -E "^..........[.+@]?[[:space:]]+[[:digit:]]+[[:space:]]+[[:alnum:]]+[[:space:]]+$GROUP" &> /dev/null

}


function fail ()
{
	SECTIONS=$((SECTIONS - 1))
	echo
	echo --------------------------------------------------------------------------------
	echo "You completed $SECTIONS sections and $STEP step(s) of the current section."
	echo 
	echo "Keep trying! If you're stuck, reread the manual and search online for answers."
	echo "If you try that and are still stuck, talk to a TA or your instructor."
	echo --------------------------------------------------------------------------------
	exit 1
}

function inc_progress()
{
	STEP=$((STEP + 1))
	return
}

function new_section()
{
	echo "You completed section $SECTIONS!"
	echo
	SECTIONS=$((SECTIONS + 1))
	STEP=0
}

echo "Section 1: Home Directory Security..."
echo

###############################################################################
# task 1 - /admins
###############################################################################
if ! dir_exists /admins
then
	echo "The /admins folder does not exist! Create it! (hint: use 'mkdir')"
	fail
fi

inc_progress

###############################################################################
# task 2 -- create groups 'emp' and 'wheel'
###############################################################################

for GROUP in emp wheel
do
	if ! group_exists $GROUP
	then
		echo "The group '$GROUP' does not exist. Create it! (hint: use 'groupadd')"
		fail
	fi
done
inc_progress

###############################################################################
# task 3 - create non-admin accounts larry, moe, and curly
###############################################################################

for ACCT in larry moe curly
do

	# check for existence

	if ! user_exists $ACCT
	then
		echo "The user '$ACCT' does not exist. Create it! (hint: use 'adduser')"
		fail
	fi
done

###############################################################################
# task 4 - create non-admin accounts larry, moe, and curly
###############################################################################

WHEEL_LINE=$(grep wheel /etc/group)
EMP_LINE=$(grep emp /etc/group)

for ACCT in larry moe curly
do
	# check for emp membership

	if ! grep $ACCT <<< $EMP_LINE &> /dev/null
	then
		echo "The user '$ACCT' is NOT in the 'emp' group!"
		echo "Add $ACCT to the emp group (hint: try usermod)."
		fail
	fi

	# make sure they're not admins

	if grep $ACCT <<< $WHEEL_LINE &> /dev/null
	then
		echo "The user '$ACCT' is in the 'wheel' group! -- $ACCT is not an admin."
		echo "Remove $ACCT from the wheel group."
		fail
	fi
done

inc_progress

###############################################################################
# task 5 - create the admins ken, dmr, bwk in /admins/username
###############################################################################


for ACCT in ken dmr bwk
do

	# check for existence

	if ! user_exists $ACCT
	then
		echo "The user '$ACCT' does not exist. Create it! (hint: use 'adduser')"
		fail
	fi

	# check for homedir location
	
	USERLINE=$(grep "^$ACCT" /etc/passwd) &> /dev/null
	
	# get homedir from USERLINE
	USERLINE=${USERLINE%:*}
	USERLINE=${USERLINE##*:}
	
	if [[ $USERLINE != "/admins/$ACCT" ]]
	then
		echo "The homedir for $ACCT is not in /admins/$ACCT!"
		echo 
		echo "Consider deleting and recreating the user with the --home option (see man adduser)."
		fail
	fi

done

inc_progress

###############################################################################
# task 6 - put admins in 'wheel' group
###############################################################################

WHEEL_LINE=$(grep wheel /etc/group)

for ACCT in ken dmr bwk
do
	# check for group membership

	if ! grep $ACCT <<< $WHEEL_LINE &> /dev/null
	then
		echo "The user '$ACCT' is NOT in the 'wheel' group! -- $ACCT is an admin!"
		echo "Add $ACCT to the wheel group (hint: try usermod)."
		fail
	fi
done

inc_progress

###############################################################################
# task 7 - ken group members
###############################################################################

if ! grep ^ken /etc/group | grep bwk | grep dmr | grep larry  &> /dev/null
then
	echo "Someone is missing from ken's group: it should have bwk, dmr, and larry in any order, but had:"
	grep ^ken /etc/group
	fail
fi

if grep ^ken /etc/group | grep moe &> /dev/null || grep ^ken /etc/group | grep curly &> /dev/null
then
	echo "Someone is in ken's group who shouldn't be!"
	grep ^ken /etc/group
	fail
fi

inc_progress

###############################################################################
# task 8 - dmr group members
###############################################################################

if ! grep ^dmr /etc/group | grep curly | grep ken | grep bwk  &> /dev/null
then
	echo "Someone is missing from dmr's group: it should have curly, ken, and bwk in any order, but had:"
	grep ^dmr /etc/group
	fail
fi

if grep ^dmr /etc/group | grep larry &> /dev/null || grep ^dmr /etc/group | grep moe &> /dev/null
then
	echo "Someone is in dmr's group who shouldn't be!"
	grep ^dmr /etc/group
	fail
fi

inc_progress



###############################################################################
# task 9 - bwk group members
###############################################################################

if ! grep ^bwk /etc/group | grep moe | grep dmr | grep ken &> /dev/null
then
	echo "Someone is missing from bwk's group: it should have moe, dmr, and ken in any order, but had:"
	grep ^bwk /etc/group
	fail
fi

if grep ^bwk /etc/group | grep larry &> /dev/null || grep ^bwk /etc/group | grep curly &> /dev/null
then
	echo "Someone is in bwk's group who shouldn't be!"
	grep ^bwk /etc/group
	fail
fi

inc_progress

###############################################################################
# task 10 - /emp/empdir permissions
###############################################################################

for EMP in larry moe curly
do

	# other should have no permissions
	if ! ls -al /emp | grep $EMP | grep -E "^d......---" &> /dev/null
	then
		echo "Homedir /emp/$EMP has incorrect permissions -- the 'other' group has permissions!"
		ls -al /emp | grep $EMP
		fail
	fi
	
	# the group should have r-x
	if ! ls -al /emp | grep $EMP | grep -E "^d...r-x---" &> /dev/null
	then
		echo "Homedir /emp/$EMP has incorrect group permissions!"
		ls -al /emp | grep $EMP
		fail
	fi
	
	# the owner should have rwx
	if ! ls -al /emp | grep $EMP | grep -E "^drwxr-x---" &> /dev/null
	then
		echo "Homedir /emp/$EMP has incorrect permissions for the owner!"
		ls -al /emp | grep $EMP
		fail
	fi

done

inc_progress

###############################################################################
# task 11 - permissions on /emp
###############################################################################

# 'other' permissions on emp should be --x
if ! ls -al / | grep emp | grep -E "^d......--x" &> /dev/null
then
	echo "The 'other' group  can read or write on /emp, or it CAN'T execute on /emp."
	echo "If the other group can't execute onemp, you won't be able to log in!!!"
	ls -al / | grep emp
	fail
fi


# wheel should be the group of the emp directory to enable admin access

if ! test_path_owner /emp root
then
	echo "emp should be owned by root. (hint: chown)"
	ls -al / | grep emp
	fail
fi

if ! test_path_group /emp wheel
then
	echo "/emp should be group 'wheel' (hint: chgrp)"
	ls -al / | grep emp
	fail
fi

# permissions on emp should be rwxrwx--x
if ! ls -al / | grep emp | grep -E "^d...rwx--x" &> /dev/null
then
	echo "The wheel group does not have correct permissions on /emp."
	ls -al / | grep emp
	fail
fi

inc_progress


###############################################################################
# task 12 - permissions on /admins/*
###############################################################################

for OLDBIE in ken dmr bwk
do

	# ownership of admin homedirs should be ken:ken, etc.
	if ! ls -al /admins | grep $OLDBIE | grep -E "$OLDBIE.+$OLDBIE" &> /dev/null
	then
		echo "Owner or group for /admins/$OLDBIE is not correct."
		ls -al /admins | grep $OLDBIE
		fail
	fi
	
	# permissions for oldbie homedirs
	if ! ls -al /admins | grep $OLDBIE | grep -E "^d......r-x" &> /dev/null
	then
		echo "The 'other' group permissions on /admins/$OLDBIE are not correct."
		ls -al /admins | grep $OLDBIE
		fail
	fi

	if ! ls -al /admins | grep $OLDBIE | grep -E "d...rwsr-x" &> /dev/null
	then
		echo "The 'group' permissions on /admins/$OLDBIE are not correct."
		ls -al /admins | grep $OLDBIE
		if ! ls -al /admins | grep $OLDBIE | grep -E "d.....s..." &> /dev/null
		then
			echo "(Have you looked into the SGID bit?)"
		fi
		fail
	fi

	if ! ls -al /admins | grep $OLDBIE | grep -E "drwxrwsr-x" &> /dev/null
	then
		echo "Owner permissions on /admins/$OLDBIE are not correct."
		ls -al /admins | grep $OLDBIE
		fail
	fi

done

inc_progress
new_section

echo "Section $SECTIONS: The Ballot Box..."
echo

###############################################################################
# task 1 - /ballots
###############################################################################
if ! dir_exists /ballots
then
	echo "The /ballots folder does not exist! Create it! (hint: use 'mkdir')"
	fail
fi

inc_progress

###############################################################################
# task 2 - /ballots owner and permissions
###############################################################################

if ! test_path_owner /ballots root
then
	echo "The root user doesn't own /ballots!"
	ls -al / | grep ballots
	fail
fi

# other permissions (other users)

if ! path_has_modebit /ballots "^d........x"
then
	echo "Other users cannot access /ballots (but they need to!)."
	ls -al / | grep ballots
	fail
fi


if ! path_has_modebit /ballots "^d.......w."
then
	echo "Other users cannot write to /ballots (and they need to!)."
	ls -al / | grep ballots
	fail
fi

if path_has_modebit /ballots "^d......r.."
then
	echo "Other users are able to read /ballots (they shouldn't be able to!)."
	ls -al / | grep ballots
	fail
fi

###############################################################################
# task 3 - /ballots group ownership and permissions
###############################################################################

if ! test_path_group /ballots wheel
then
	echo "The group is not correct for /ballots!"
	ls -al / | grep ballots
	fail
fi

# make sure wheel can't access /ballots without sudo

if path_has_modebit /ballots "^d.....x..."
then
	echo "Members of the 'wheel' group can access (use) /ballots..."
	ls -al / | grep ballots
	fail
fi

if path_has_modebit /ballots "^d...r....."
then
	echo "Members of the 'wheel' group can read /ballots..."
	ls -al / | grep ballots
	fail
fi

if path_has_modebit /ballots "^d....w...."
then
	echo "Members of the 'wheel' group can write to /ballots..."
	ls -al / | grep ballots
	fail
fi

inc_progress
new_section

echo "Section $SECTIONS: The TPS Reports Directory..."
echo

###############################################################################
# task 1 - /tpsreports
###############################################################################
if ! dir_exists /tpsreports
then
	echo "The /tpsreports folder does not exist! Create it! (hint: use 'mkdir')"
	fail
fi

inc_progress

###############################################################################
# task 2 - /tps user
###############################################################################

if ! user_exists tps
then
	echo "The 'tps' user does not exist! Try adduser..."
	fail
fi

inc_progress

###############################################################################
# task 3 - /tps ownership and perms
###############################################################################

PROOF=$(ls -al / | grep tpsreports)

if ! test_path_owner /tpsreports tps
then
	echo "/tpsreports is not owned by 'tps'."
	echo $PROOF
	fail
fi

if ! test_path_group /tpsreports wheel
then
	echo "/tpsrepAorts is not group 'wheel' (hint: try chgrp)."
	echo $PROOF
	fail
fi

if ! path_has_modebit /tpsreports "^d....w...."
then
	echo "The 'wheel' group cannot write to /tpsreports."
	echo $PROOF
	fail
fi

if ! path_has_modebit /tpsreports "^d...r....."
then
	echo "The 'wheel' group cannot read /tpsreports."
	echo $PROOF
	fail
fi

if path_has_modebit /tpsreports "^d........x"
then
	echo "The 'other' group can access (execute) /tpsreports, but shouldn't be able to."
	echo $PROOF
	fail
fi

if path_has_modebit /tpsreports "^d......r.."
then
	echo "The 'other' group can read /tpsreports, but shouldn't be able to."
	echo $PROOF
	fail
fi

if path_has_modebit /tpsreports "^d.......w."
then
	echo "The 'other' group can write to /tpsreports, but shouldn't."
	echo $PROOF
	fail
fi

if  path_has_modebit /tpsreports "^d.....x..."
then
	echo "The 'wheel' group has access (execute) on /tpsreports; this is necessary but not"
	echo "sufficient."
	echo "Files written into this directory will have the group of the file creator, not"
	echo "the group of /tpsreports, as required by the question. (See the SGID bit on dirs.)"
	echo $PROOF
	fail
fi

if path_has_modebit /tpsreports "^d.....S..."
then
	echo "The SGID bit is set on /tpsreports, but the group does not have 'x' permissions."
	echo "To represent this, the SGID bit is a capital letter 'S'."
	echo $PROOF
	fail
fi

if ! path_has_modebit /tpsreports "^d.....s..."
then
	echo "Files written into this directory will have the group of the file's"
	echo "creator, not the group of this directory. (See the SGID bit on dirs.)"
	echo $PROOF
	fail
fi

inc_progress

###############################################################################
# task 4 - protecting users from each other
###############################################################################

if ! path_has_modebit /tpsreports "^d........T"
then
	echo "The sticky bit is not set on /tpsreports, which allows group members to delete"
	echo "each others' files. (Read about setting the sticky bit.)"
	echo $PROOF
	fail
fi

inc_progress

###############################################################################
echo "You completed section $SECTIONS!"
echo

echo "Congrats! You finished everything this script can grade."
echo "Don't forget about the short answer questions!"

exit 0
