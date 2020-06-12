# Migration from Google Code SVN to git

- From: https://code.google.com/archive/p/adiumbook/source
- Date: 2020-06-10

## Instructions

- https://stackoverflow.com/a/61198215
- https://stackoverflow.com/a/29669021

## Download SVN repository

```bash
mkdir adiumbook
cd adiumbook
wget https://storage.googleapis.com/google-code-archive-source/v2/code.google.com/adiumbook/repo.svndump.gz
gunzip repo.svndump.gz
```

## Recreate local SVN repo

```bash
svnadmin create svn
svnadmin load svn < repo.svndump
```

## Create Git repo from SVN repo

```bash
git svn clone file://$PWD/svn adiumbook --stdlayout -A authors.txt
```

## Move all repository files into a 'xcode' directory

```bash
# https://stackoverflow.com/a/21558567
git filter-branch --tree-filter \
    "mkdir /tmp/xcode; mv * /tmp/xcode || true; mv /tmp/xcode ." \
    HEAD
```

## Create all the release tags

Find all the release commits:

```console
$ git log --oneline --reverse | egrep 'Initial import|Upgrading|NIB file| 1.5 |closes issue #35'
71e7c3c Initial import
438c489 Upgrading to release 1.1
0180da9 Upgrading to release 1.2
788c4cf Upgrading to release 1.3
61d274b - Removed backup of NIB file
31629b0 Upgrading to release 1.4
ad278c7 That's it: release 1.5 finished.
1622a1a Fixed the "Address Book contacts with no IM" report under Snow Leopard (closes issue #35)
```

Massage that result in the text editor to compose the `git tag` commands:

```bash
git tag v1.0   71e7c3c
git tag v1.1   438c489
git tag v1.2   0180da9
git tag v1.3   788c4cf
git tag v1.3.1 61d274b
git tag v1.4   31629b0
git tag v1.5   ad278c7
git tag v1.5.1 1622a1a
```
