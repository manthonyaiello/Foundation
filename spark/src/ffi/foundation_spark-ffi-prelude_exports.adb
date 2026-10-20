--  The exports Cryptol calls for the Cryptol prelude in SPARK: each
--  forwards to its ghost shim.

package body Foundation_Spark.FFI.Prelude_Exports with
  SPARK_Mode
is

   function Foldl (N : C_Size; Z : Byte; Xs : Fold_Buffer) return Byte is
     (Ghost_Foldl (N, Z, Xs));

   function Foldl_Enumeration (From, To : C_Size; E, Z : Byte) return Byte is
     (Ghost_Foldl_Enumeration (From, To, E, Z));

   function Bit_8 (X, J : Byte) return Byte is (Ghost_Bit_8 (X, J));

   function Head_8 (X : Byte) return Byte is (Ghost_Head_8 (X));

   function Bit_32 (X : Word_32; J : Byte) return Byte is
     (Ghost_Bit_32 (X, J));

   function Bit_15 (X : Word_16; J : Byte) return Byte is
     (Ghost_Bit_15 (X, J));

   function Join_Bytes (Xs : Four_Bytes) return Word_32 is
     (Ghost_Join_Bytes (Xs));

   procedure Split_Word (X : Word_64; Output : out Two_Words) is
   begin
      Ghost_Split_Word (X, Output);
   end Split_Word;

   procedure Join_Words (Ws : Two_Words; Output : out Eight_Bytes) is
   begin
      Ghost_Join_Words (Ws, Output);
   end Join_Words;

   function Zero_64 return Word_64 is (Ghost_Zero_64);

   function Literal_64 (X : Word_64) return Word_64 is (Ghost_Literal_64 (X));

   procedure Repeat_4 (X : Byte; Output : out Four_Bytes) is
   begin
      Ghost_Repeat_4 (X, Output);
   end Repeat_4;

   procedure Reverse_6 (Xs : Six_Bytes; Output : out Six_Bytes) is
   begin
      Ghost_Reverse_6 (Xs, Output);
   end Reverse_6;

   procedure Bulk_Index_Block (Xs : Block; Ixs : Block; Output : out Block)
   is
   begin
      Ghost_Bulk_Index_Block (Xs, Ixs, Output);
   end Bulk_Index_Block;

   procedure Bulk_Index_Table (T : Table; Bs : Block; Output : out Block) is
   begin
      Ghost_Bulk_Index_Table (T, Bs, Output);
   end Bulk_Index_Table;

   function Ceil_Div (M, N : C_Size) return Word_64 is (Ghost_Ceil_Div (M, N));

   function Ceil_Mod (M, N : C_Size) return Word_64 is (Ghost_Ceil_Mod (M, N));

   function Pmult_8 (X, Y : Byte) return Word_16 is (Ghost_Pmult_8 (X, Y));

   function Pmult_9 (X, Y : Word_16) return Word_32 is (Ghost_Pmult_9 (X, Y));

   function Pmod_15 (X, M : Word_16) return Word_16 is (Ghost_Pmod_15 (X, M));

   function Pdiv_8 (X, Y : Byte) return Word_16 is (Ghost_Pdiv_8 (X, Y));

   function Pdiv_9 (X, Y : Word_16) return Word_16 is (Ghost_Pdiv_9 (X, Y));

end Foundation_Spark.FFI.Prelude_Exports;
