--  valgrind.h's client request on arm64-linux: the arguments' address in
--  x4, the default result in x3, the four rotations of x12 by 3, 13, 51
--  and 61 bits (128 in all: x12 is unchanged), then orr x10, x10, x10.
--  Outside Valgrind the sequence leaves every register as it was.

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
        ("mov x3, %1" & ASCII.LF & ASCII.HT
         & "mov x4, %2" & ASCII.LF & ASCII.HT
         & "ror x12, x12, #3  ;  ror x12, x12, #13" & ASCII.LF & ASCII.HT
         & "ror x12, x12, #51 ;  ror x12, x12, #61" & ASCII.LF & ASCII.HT
         & "orr x10, x10, x10" & ASCII.LF & ASCII.HT
         & "mov %0, x3",
         Outputs  => Unsigned_64'Asm_Output ("=r", Result),
         Inputs   =>
           [Unsigned_64'Asm_Input ("r", 0),
            System.Address'Asm_Input ("r", Args'Address)],
         Clobber  => "cc,memory,x3,x4",
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
