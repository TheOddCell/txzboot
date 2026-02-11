# txzboot
tar.xz to uki/efi converter for linux.

Instead of taking long build times it takes long usage times!

The makefile compiles dependancies and a shell script.

> Why does the script need compiling?

The final script includes busybox, the loader, and an entire kernel inside (using base64). Either way the kernel and busybox need it.
