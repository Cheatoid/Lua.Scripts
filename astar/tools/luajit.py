#!/usr/bin/env python
"""
Minimal LuaJIT 2.1 runner shim for environments without a standalone luajit binary.

This sandbox has no `luajit` executable, but `lupa` embeds LuaJIT 2.1. This shim
executes a Lua script inside that embedded runtime, providing:

  * an `arg` table like the standalone interpreter (arg[0] = script path)
  * an `os.exit(code)` override that maps to a real process exit code

The library itself is pure Lua and runs unchanged under a real `luajit`:
      luajit tests/run.lua
      luajit benchmarks/bench.lua --quick

Usage:
      python tools/luajit.py tests/run.lua
      python tools/luajit.py benchmarks/bench.lua --quick
"""
import sys

try:
    from lupa import luajit21
except ImportError:  # pragma: no cover
    print("error: lupa is not installed (pip install lupa)", file=sys.stderr)
    sys.exit(2)


SENTINEL = "__ASTAR_EXIT__"


def main():
    if len(sys.argv) < 2:
        print("usage: luajit.py script.lua [args...]", file=sys.stderr)
        return 2

    script = sys.argv[1]
    lua_args = sys.argv[2:]

    L = luajit21.LuaRuntime(unpack_returned_tuples=True)

    # Build the standard `arg` table: arg[0] = script, arg[1..n] = script args.
    arg_table = L.table()
    arg_table[0] = script
    for i, a in enumerate(lua_args):
        arg_table[i + 1] = a
    L.globals()["arg"] = arg_table

    # Override os.exit so exit codes propagate to the process.
    L.execute(
        "EXIT_CODE = 0\n"
        "os.exit = function(code)\n"
        "    EXIT_CODE = code or 0\n"
        "    error('" + SENTINEL + "', 0)\n"
        "end\n"
    )

    loader = L.eval(
        "function(s, a) "
        "  local f, err = loadfile(s) "
        "  if not f then error(err, 0) end "
        "  return f(unpack(a, 1, table.getn(a) + 1)) "  # arg table starts at 0
        "end"
    )
    # unpack over arg[0..n]: pass a 1-based copy so unpack sees the script args
    args_1based = L.table()
    for i, a in enumerate(lua_args):
        args_1based[i + 1] = a

    try:
        loader(script, args_1based)
        code = 0
    except Exception as e:  # LuaError or other
        msg = str(e)
        if SENTINEL in msg:
            code = int(L.globals()["EXIT_CODE"] or 0)
        else:
            print("lua error: %s" % msg, file=sys.stderr)
            code = 1
    return code


if __name__ == "__main__":
    sys.exit(main())
