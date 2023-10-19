#!/usr/bin/env bash

# progress checker

TOTAL=0
STEP=0
SECTIONS=1

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

echo "Section 1: Home Directory Security..."
echo

###############################################################################
# task 1 - /admins
###############################################################################
if [[ ! -d /admins ]]
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
	if ! grep "^$GROUP" /etc/group &> /dev/null
	then
		echo "The group '$GROUP' does not exist. Create it! (hint: use 'groupadd')"
		fail
	fi
done
inc_progress

###############################################################################
# task 3 - create non-admin accounts larry, moe, and curly
###############################################################################

WHEEL_LINE=$(grep wheel /etc/group)
EMP_LINE=$(grep emp /etc/group)

for ACCT in larry moe curly
do

	# check for existence

	if ! grep "^$ACCT" /etc/passwd &> /dev/null
	then
		echo "The user '$ACCT' does not exist. Create it! (hint: use 'adduser')"
		fail
	fi

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
# task 5 - create the admins ken, dmr, bwk
###############################################################################


for ACCT in ken dmr bwk
do

	# check for existence

	if ! grep "^$ACCT" /etc/passwd &> /dev/null
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
echo "You did it!"
