# MLua Tasks

This document roughly covers MLua deliverable number 1.8.1.1 [defined here](https://dev.anet.be/doc/brocade/mlua/html/mlua.html#embedding-m-in-lua). It is the most significant MLua deliverable.

## Current state

1. M can open a connection to Lua and vice versa.
2. Lua and M can share data via lua-yottadb (which is now bug-fixed)
3. Build and install works.
4. Risks can cautions have been are researched, documented, and appropriate tasks added below.

However, a) improvement is needed on data sharing efficiency and syntax, and b) Lua cannot yet 'callin' to an M function. These have been proposed as the next tasks.

## Syntax and Macros

7d (=3wk): Improvement is needed on data sharing efficiency and syntax. I propose a solution by making ydb globals act like Lua tables. A breakdown of this task is outlined in [proposal.md](/src/tasks/proposal.md).

7d (=3wk): Ability for Lua to call an M function and invoke an M4 macro. Breakdown as follows:

* 2d: understand M4 macros typical uses
* 4d: create a way to invoke M4 macros from Lua and use the data in Lua (task duration uncertain). Requires implementing ydb 'callins' from Lua (lua-yottadb does not implement these).
* 1d: alpha release of MLua to developers to play with and give feedback; process their feedback

The above alpha release is the first major milestone of MLua: defining and implementing how interaction works and data is shared.

## Cmumps

One of my outstanding tasks is to review cmumps code (1wk). Is this a good stopping point at which to do so - discuss?

* 2.5d (1wk): review cmumps code and provide suggestions

## Robustness

10d (=4wk): Robustness improvements:

* 4d: create test cases for everything now that it is somewhat stable
* 2.5d: Write wrappers for all Lua I/O functions to re-try on EINTR error -- per ydb recommendation
* 0.5d: Handle memory full in lua-yottadb functions.
