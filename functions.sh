#!/usr/bin/env bash

gerrit_cmd() { ssh -q -n -p 29418 -l admin gerrit-server.example.org gerrit "$@"; }
