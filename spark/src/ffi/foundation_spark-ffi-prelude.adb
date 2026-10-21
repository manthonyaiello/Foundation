--  The ghost shims for the Cryptol prelude in SPARK: each returns, or
--  writes, its instance's result.

package body Foundation_Spark.FFI.Prelude with
  SPARK_Mode
is

   function Foldl (N : C_Size; Z : Byte; Xs : Fold_Buffer) return Byte is
     (Byte_Folds.Foldl (Z, Xs (0 .. Natural (N) - 1)));

   function Foldl_Enumeration (From, To : C_Size; E, Z : Byte) return Byte is
     (Byte_Enumeration_Folds.Foldl (E, Z, Integer (From), Integer (To)));

   function Bit_8 (X, J : Byte) return Byte is
     (Bit_Byte (Byte_Words.Word_Bits.Bit (X, Natural (J))));

   function Head_8 (X : Byte) return Byte is
     (Bit_Byte (Byte_Words.Word_Bits.Head (X)));

   function Bit_32 (X : Word_32; J : Byte) return Byte is
     (Bit_Byte (SHA2.SHA256.Word_Sequences.Word_Bits.Bit (X, Natural (J))));

   function Bit_15 (X : Word_16; J : Byte) return Byte is
     (Bit_Byte (Bits_15.Bit (X, Natural (J))));

   function Join_Bytes (Xs : Four_Bytes) return Word_32 is
     (SHA2.SHA256.Word_Sequences.Value (Byte_Words.Join (Xs), 0, 32));

   procedure Split_Word (X : Word_64; Output : out Two_Words)
   is
      P : constant SHA2.Bits := Bits_Of_64 (X);
   begin
      Output :=
        [SHA2.SHA256.Word_Sequences.Split_At (P, 0),
         SHA2.SHA256.Word_Sequences.Split_At (P, 1)];
   end Split_Word;

   procedure Join_Words (Ws : Two_Words; Output : out Eight_Bytes) is
      P : constant SHA2.Bits := SHA2.SHA256.Word_Sequences.Join (Ws);
   begin
      Output :=
        [for K in Eight_Bytes'Range =>
           Byte_Words.Split_At (P, SHA2.Bit_Index (K))];
   end Join_Words;

   function Zero_64 return Word_64 is
     (Words_64_Bits.Value (SHA2.Sequences_Of_Bits.Zero (64), 0, 64));

   function Literal_64 (X : Word_64) return Word_64
   is
     (Words_64_Bits.Value
        (SHA2.Sequences_Of_Bits.Literal (SHA2.Bit_Index (X), 64), 0, 64));

   procedure Repeat_4 (X : Byte; Output : out Four_Bytes) is
   begin
      Output := HMAC.Byte_Sequences.Repeat (4, X);
   end Repeat_4;

   procedure Reverse_6 (Xs : Six_Bytes; Output : out Six_Bytes) is
   begin
      Output := HMAC.Byte_Sequences.Reverse_Of (Xs);
   end Reverse_6;

   procedure Bulk_Index_Block (Xs : Block; Ixs : Nibbles; Output : out Block)
   is
   begin
      Output := Block_Bulk_Indexing.Bulk_Index (Xs, Ixs);
   end Bulk_Index_Block;

   procedure Bulk_Index_Table (T : Table; Bs : Block; Output : out Block) is
   begin
      Output := Table_Bulk_Indexing.Bulk_Index (T, Bs);
   end Bulk_Index_Table;

   function Ceil_Div (M, N : C_Size) return Word_64 is
     (Word_64
        (Lengths.Ceil_Div (SHA2.Bit_Index (M), SHA2.Bit_Index (N))));

   function Ceil_Mod (M, N : C_Size) return Word_64 is
     (Word_64
        (Lengths.Ceil_Mod (SHA2.Bit_Index (M), SHA2.Bit_Index (N))));

   function Pmult_8 (X, Y : Byte) return Word_16 is
     (Pmult_7_7.Pmult (Word_16 (X), Word_16 (Y)));

   function Pmult_9 (X, Y : Word_16) return Word_32
   is
     (Pmult_8_8.Pmult (Word_32 (X), Word_32 (Y)));

   function Pmod_15 (X, M : Word_16) return Word_16
   is
     (Pmod_15_8.Pmod (X, M));

   function Pdiv_8 (X, Y : Byte) return Word_16 is
     (Pdiv_8_8.Pdiv (Word_16 (X), Word_16 (Y)));

   function Pdiv_9 (X, Y : Word_16) return Word_16
   is
     (Pdiv_9_9.Pdiv (X, Y));

end Foundation_Spark.FFI.Prelude;
