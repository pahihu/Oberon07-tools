MODULE DynLoad ["C"] EXTERNAL ["dl"];  (* C land ahead.  Enter at your own risc! *)

IMPORT
  C := CType;
  
CONST
  RTLD_LAZY* = 0;
  RTLD_NOW* = 0;
  RTLD_GLOBAL = 2;
  RTLD_LOCAL = 4;
  RTLD_DEFAULT* = 0;
  RTLD_NEXT* = 0;

PROCEDURE dlopen* (file: C.charPtr1d; mode: C.int): C.address;
PROCEDURE dlclose* (handle: C.address): C.int;
PROCEDURE dlsym* (handle: C.address; name: ARRAY OF C.char): C.address;
PROCEDURE dlerror* (): C.address;
  
END DynLoad.
