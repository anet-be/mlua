# MLua Tasks

This document break into smaller tasks, the MLua deliverable number 1.8.1.1 [defined here](https://dev.anet.be/doc/brocade/mlua/html/mlua.html#embedding-m-in-lua), which is the most significant MLua deliverable.

## Current state

- M can open a connection to Lua and vice versa, and runs MLUA_INIT env var at startup
- Lua and M can share data via lua-yottadb (which is now bug-fixed)
- Build and install works.
- Risks can cautions have been are researched, documented, and appropriate tasks added below.

However, a) improvement is needed on data sharing efficiency and syntax, and b) Lua cannot yet 'callin' to an M function. These have been proposed as the next tasks.

## Syntax and Macros

1. 7d (=3wk): Improvement is needed on data sharing efficiency and syntax. I propose a solution by making ydb globals act like Lua tables.
   - A breakdown of this task is outlined in [proposal.md](./proposal.md).
2. 7d (=3wk): Ability for Lua to call an M function and invoke an M4 macro. Breakdown as follows:

   - 2d: understand M4 macros typical uses
   
   - 4d: create a way to invoke M4 macros from Lua and use the data in Lua (task duration uncertain). Requires implementing ydb 'callins' from Lua (lua-yottadb does not implement these).
   
   - 1d: alpha release of MLua to developers to play with and give feedback; process their feedback

The above alpha release is the first major milestone of MLua: defining and implementing how interaction works and data is shared.

## Benchmarks

3. 3.5d (=1.5wk): Create a set of benchmarks for MLua. Use [YottaWeb-Test](https://yottadb.com/comparing-yottadb-web-framework-performance/) as a baseline starting point to compare against:

   - 1d: Create minimal web baseline test of just the fast Lua part of YottaWebTest using gitpod for equivalent comparison

- 2.5d: Add a testing functionality typically provided by cmumps. Compare against cmumps for speed.

## Cmumps

4. 4.5d (=2wk): One of my outstanding tasks is to review cmumps code (1wk). Is this a good stopping point at which to do so - discuss?

- 2.5d (1wk): review cmumps code and provide suggestions

- 2d Integrate MLua and mxxhash into cmumps (as a master collector) for deployment into qtechng. Discuss with Bart/Luc


## Robustness

5. 10d (=4wk): Robustness improvements:

- 4d: create test cases for everything now that it is somewhat stable

- 2.5d: Write wrappers for all Lua I/O functions to re-try on EINTR error -- per ydb recommendation

- 0.5d: Handle memory full in lua-yottadb functions.

