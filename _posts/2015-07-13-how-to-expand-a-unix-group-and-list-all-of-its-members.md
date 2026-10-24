---
layout: post
title: How to expand a UNIX group and list all of its members
date: 2015-07-13
description: >
  A Perl function that lists every member of a UNIX group, primary and
  secondary, without shelling out to getent or id.
categories:
  - Perl
---

Recently, I needed a way to show all of the members of a UNIX group. I’m in the process of writing a sudoers parser and this functionality was needed to show which users could actually run which commands as which users. After doing some internet research, I came across the following link: <http://stackoverflow.com/questions/2835368/how-to-list-all-users-in-a-linux-group>.

Though it worked, it relied on UNIX commands to build the hash, getent and id. It was very slow. The function below uses native perl to iterate through the users and their primary groups and then adds to the hash all of the secondary group memberships, therefore making the complete list of group members.

```perl
#!/usr/bin/env perl

use strict;
my $arg=shift;
my %groupMembers; # defining outside of function so that hash is only built once for multiple function calls

sub expandGroupMembers{
    my $groupQuery=shift;
    unless (%groupMembers){
        while (my($name,$pass,$uid,$gid,$quota,$comment,$gcos,$dir,$shell,$expire)=getpwent()) {
                my $primaryGroup=getgrgid($gid);
                $groupMembers{$primaryGroup}->{$name}=1;
        }
        while (my($gname,$gpasswd,$gid,$members)=getgrent()) {
                foreach my $member (split / /, $members){
                        $groupMembers{$gname}->{$member}=1;
                }
        }
    }
    my $membersConcat=join(",",sort keys %{$groupMembers{$groupQuery}});
    return "$membersConcat" || "$groupQuery Does not exist";
}
print &expandGroupMembers($arg)."\n";
```

The above code yields the following result:

```
$ ./lusers blah
blah Does not exist

$ ./lusers admin
user1,root
```
