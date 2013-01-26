# Threading
 * When training, tokenize in a separate thread, queueing the replies back
 * <http://sqlite.org/c3ref/enable_shared_cache.html>
 * Find a threading library
    * Lanes looks nice, but has some issues on Linux
    * Ray looks promising, but isn't ready yet
    * llthreads works, but is not ideal, can only create new threads
      from code strings or files

# `lpeg_utf8` (<https://gist.github.com/2958879>)
 * Wait for it to be released to LuaRocks or merged into lpeg

# Documentation
 * Use ldoc
 * Replace debugging print calls with proper tracing

# Finish tokenizer, add more tests from Hailo

# Flesh out the reply generation
 * Add scorers
 * Make use of the links.count column
 * Generate multiple replies concurrently

# Create/drop indexes when needed

# Progress reporting for `flush_cache()`

# Add command-line interface
 * option parsing

# Add readline-ish interface
 * use lua-linenoise

# Add tcp server interface
 * Use luasocket or Ray for sockets
 * Daemonize with luadaemon
