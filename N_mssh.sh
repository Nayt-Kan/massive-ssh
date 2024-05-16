#!/bin/bash

#==||clearing logs files||==#

> results.log
> errors.log
> wrong_host.log
> timeout.log

#==||messages||==#

help="\
Usage: N_test.sh { command } { options } \n\
where  command := { --ssh | --scp } \n\
       options := { --file [name] | --from | --to } \n\
"

error="\
Try 'N_mssh.sh -h' for more information. \n\
"

#==||defolt parameters||==#

hosts=hosts.txt
d_port=2222
d_user=user
timeout=10
max_threads=5

#ssh_id=/home/user/.ssh/id_rsa
#ssh_id=~/.ssh/id_rsa
ssh_id=$HOME/.ssh/id_rsa

#==||reading variables||==#

while [ -n "$1" ]
do
  case "$1" in
       -h) error="$help" ;;
    --scp) mcp="scp" ;;
    --ssh) msh="ssh"
           shcmd=$2
                 shift ;;
   --file) hosts=$2
                 shift ;;
   --from) from=$2
                 shift ;;
     --to) to=$2
                 shift ;;
  esac
  shift
done

#==||request verification||==#

[[ -n `echo $shcmd | grep -E '^-'` ]] && sc=101
[[ -n `echo $hosts | grep -E '^-'` ]] && sc=102
[[ -n `echo $from | grep -E '^-'` ]] && sc=103
[[ -n `echo $to | grep -E '^-'` ]] && sc=104

[[ -n "$mcp" && -z "$from" ]] && sc=105
[[ -n "$mcp" && -z "$to" ]] && sc=106
[[ -n "$msh" && -z "$shcmd" ]] && sc=107

[[ -n "$msh" && -n "$shcmd" ]] || \
[[ -n "$mcp" && -n "$from" && -n "$to" ]] || \
sc=108

#==||status code processing||==#

if [ -n "$sc" ]
then
  case "$sc" in
    101) echo "missing parameter for 'ssh'" ;;
    102) echo "missing parameter for 'file'" ;;
    103) echo "missing parameter for 'from'" ;;
    104) echo "missing parameter for 'to'" ;;
    105) echo "Have no 'from' parameter" ;;
    106) echo "Have no 'to' parameter" ;;
    107) echo "Have no parameter for ssh \n" ;;
    108) ;;
      *) echo "sc = $sc" ;;
  esac

printf "$error"
exit

fi

#==||reassigning parameters||==#

lines=`wc -l $hosts | cut -d" " -f1`
[ $lines -lt $max_threads ] && max_threads=$lines

#==||preparing hosts||==#

while read line
do
((i=i%max_threads)); ((i++==0)) && wait
((j++))
(
line="${line//$'\r'/}" # for win files; changes End Of Line(win) to Line Feed (unix)

host=`echo $line | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | cut -d@ -f2 | cut -d: -f1`
user=`echo $line | grep @ | cut -d@ -f1`
port=`echo $line | grep : | cut -d: -f2`

[ -n "$host" ] || sc=201
[ -n "$user" ] || user=$d_user
[ -n "$port" ] || port=$d_port

#==||preparing request||==#

if [ -z "$sc" ]
then
  #==||scp||==#
  if [ -n "$mcp" ]
  then
    scp -o ConnectTimeout=$timeout -P $port -i $ssh_id $from $user@$host':'$to &>>results.log
  [ $? != 0 ] && sc=203 || echo "scp for line $j ready"
  fi
  #==||ssh||==#
  if [ -n "$msh" ]
  then
    ssh -o ConnectTimeout=$timeout -p $port -i $ssh_id $user@$host $shcmd &>>results.log
    [ $? != 0 ] && sc=202 || echo "ssh for line $j redy"
  fi
fi

#==||status code processing||==#

if [ -n "$sc" ]
then
  case "$sc" in
    201) echo $line >> wrong_host.log
         echo "line $j is a wrong" ;;
    202) echo $line >> timeout.log
         echo "ssh for line $j N/A" ;;
    203) echo $host >> timeout.log
         echo "scp for line $j N/A" ;;
      *) echo "sc = $sc" ;;
  esac
fi

)&
done < $hosts
wait
