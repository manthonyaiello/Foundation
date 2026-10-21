--  Memcheck's client requests MAKE_MEM_UNDEFINED and MAKE_MEM_DEFINED
--  (valgrind/memcheck.h), for the ctgrind-style test ct_grind (issue #50):
--  marking a secret "undefined" makes Memcheck report every conditional
--  branch, and every memory address, computed from it. The body is per
--  architecture (src/arch-aarch64, src/arch-x86_64; ct.gpr's CT_ARCH): the
--  special instruction sequence of valgrind.h, which does nothing outside
--  Valgrind.

with System;

package CT_Valgrind is

   procedure Make_Undefined (Addr : System.Address; Len : Natural);
   --  Memcheck: VALGRIND_MAKE_MEM_UNDEFINED (Addr, Len).
   --  @param Addr The first byte.
   --  @param Len The number of bytes.

   procedure Make_Defined (Addr : System.Address; Len : Natural);
   --  Memcheck: VALGRIND_MAKE_MEM_DEFINED (Addr, Len).
   --  @param Addr The first byte.
   --  @param Len The number of bytes.

end CT_Valgrind;
