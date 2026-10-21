--  valgrind.h's client request on amd64-linux: the arguments' address in
--  rax, the default result in rdx, the four rotations of rdi by 3, 13, 61
--  and 51 bits (128 in all: rdi is unchanged), then xchg rbx, rbx.
--  Outside Valgrind the sequence leaves every register as it was.
--
--  UNTESTED: written on aarch64 (issue #50); the x86_64 IOD session
--  compiles and runs it first.

with Interfaces;
with System.Machine_Code;
with System.Storage_Elements;

package body CT_Valgrind is

   use Interfaces;

   Tool_Base_MC : constant := 16#4D43_0000#;
   --  VG_USERREQ_TOOL_BASE ('M', 'C'), Memcheck's requests.

   type Request_Args is array (0 .. 5) of Unsigned_64;
   --  _zzq_args: the request and its five arguments.

   procedure Request (Code : Unsigned_64; A1, A2 : Unsigned_64);
   --  VALGRIND_DO_CLIENT_REQUEST_STMT (Code, A1, A2, 0, 0, 0).
   --  @param Code The request.
   --  @param A1 Its first argument.
   --  @param A2 Its second argument.

   procedure Request (Code : Unsigned_64; A1, A2 : Unsigned_64) is
      Args   : aliased Request_Args := [Code, A1, A2, 0, 0, 0]
      with Volatile;
      Result : Unsigned_64;
   begin
      System.Machine_Code.Asm
        ("rolq $3,  %%rdi ; rolq $13, %%rdi" & ASCII.LF & ASCII.HT
         & "rolq $61, %%rdi ; rolq $51, %%rdi" & ASCII.LF & ASCII.HT
         & "xchgq %%rbx,%%rbx",
         Outputs  => Unsigned_64'Asm_Output ("=d", Result),
         Inputs   =>
           [System.Address'Asm_Input ("a", Args'Address),
            Unsigned_64'Asm_Input ("0", 0)],
         Clobber  => "cc,memory",
         Volatile => True);
      pragma Unreferenced (Result);
   end Request;

   procedure Make_Undefined (Addr : System.Address; Len : Natural) is
   begin
      Request (Tool_Base_MC + 1,
               Unsigned_64 (System.Storage_Elements.To_Integer (Addr)),
               Unsigned_64 (Len));
   end Make_Undefined;

   procedure Make_Defined (Addr : System.Address; Len : Natural) is
   begin
      Request (Tool_Base_MC + 2,
               Unsigned_64 (System.Storage_Elements.To_Integer (Addr)),
               Unsigned_64 (Len));
   end Make_Defined;

end CT_Valgrind;
